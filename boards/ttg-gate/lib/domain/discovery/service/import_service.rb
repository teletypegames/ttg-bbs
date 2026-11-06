# frozen_string_literal: true

module Discovery
  # The daily import (bin/discovery-import): every enabled source is fetched,
  # parsed and laid over the catalog by host:port; then each board's fields
  # are resolved by the source priority, its delisted mark set, the aliases,
  # opt-outs and tags rebuilt.
  #
  # A source whose parse lost more than half of its records since the last
  # good import is not applied (its old records stay) and an alert goes out:
  # a format change must not wipe half a list. A source that cannot be
  # fetched or parsed keeps its old records the same way.
  class ImportService
    # The share of the last record count a parse must keep.
    KEEP = 0.5

    Outcome = Data.define(:source, :status, :records, :message)

    # [config]  a ConfigRepository  [fetcher] a SourceFetcher
    # [tags]    a TagService        [aliases] an AliasService
    # [optout]  an OptoutRepository
    # [alert]   called with a message on a refused or failed source
    def initialize(config:, fetcher:, tags:, aliases:, optout:, alert: ->(_) {})
      @config  = config
      @fetcher = fetcher
      @tags    = tags
      @aliases = aliases
      @optout  = optout
      @alert   = alert
    end

    # Imports the enabled sources (only +only+, a list of ids, when given);
    # +files+ maps a source id to a local file to read instead of its URL.
    # Returns an Outcome a source.
    def call(only: nil, files: {}, now: Time.now.to_i)
      MetaModel.store('started_at', now) unless MetaModel.value('started_at')
      enabled = @config.sources.select(&:enabled?)
      BoardSourceModel.deactivate_other_sources(enabled.map(&:id))
      outcomes = enabled.select { |s| only.nil? || only.include?(s.id) }.map { |s| import(s, files[s.id], now) }
      resolve(now)
      @aliases.rebuild
      apply_optout
      @tags.refresh_all(now: now)
      MetaModel.store('last_import_at', now)
      outcomes
    end

    # Fetches, parses and applies one source.
    def import(source, file, now)
      records = records(source, file, now)
      previous = SourceModel.where(id: source.id).get(:record_count).to_i
      return refuse(source, records.size, previous, now) if previous.positive? && records.size < previous * KEEP

      BoardSourceModel.apply(source.id, records, now)
      SourceModel.save_config(source, last_parse_at: now, record_count: records.size, last_error: nil)
      Outcome.new(source: source.id, status: :ok, records: records.size, message: nil)
    rescue SourceFetcher::FetchError, KeyError, SystemCallError, ArgumentError, EncodingError => e
      fail_source(source, "#{e.class}: #{e.message}", now)
    end

    private

    # The RecordModels of +source+, from +file+ when given, else fetched.
    def records(source, file, now)
      SourceModel.save_config(source)
      bytes = file ? File.binread(file) : @fetcher.fetch(source)
      SourceModel.save_config(source, last_fetch_at: now)
      Parsers.for(source.format).parse(bytes, source)
    end

    def refuse(source, count, previous, now)
      message = "#{source.name}: the parse gave #{count} records against #{previous} last time " \
                '(more than half lost); not applied, the old records stay'
      SourceModel.save_config(source, last_error: message, last_error_at: now, refused_at: now)
      @alert.call(message)
      Outcome.new(source: source.id, status: :refused, records: count, message: message)
    end

    def fail_source(source, message, now)
      SourceModel.save_config(source, last_error: message, last_error_at: now)
      @alert.call("#{source.name}: #{message}")
      Outcome.new(source: source.id, status: :failed, records: 0, message: message)
    end

    # The fields of every board from its active sources by priority (from all
    # it ever had when it is delisted), with their provenance.
    def resolve(now)
      rank = @config.priority.each_with_index.to_h
      BoardModel.db.transaction { BoardModel.ids.each { |id| resolve_board(id, rank, now) } }
    end

    def resolve_board(id, rank, now)
      rows = BoardSourceModel.of(id)
      active = rows.select { |r| r[:active] == 1 }
      ranked = (active.empty? ? rows : active).sort_by { |r| [rank.fetch(r[:source_id], rank.size), -r[:last_seen_at]] }
      BoardModel.resolve(id, *best_fields(ranked), active.empty?, now)
    end

    # [the fields, the source of each] of +ranked+ source rows: each field
    # from the first row that has it, text cleaned again (Address.text), as
    # the rows of an older import may hold control characters.
    def best_fields(ranked)
      RecordModel::FIELDS.map(&:to_s).each_with_object([{}, {}]) do |field, (fields, provenance)|
        row = ranked.find { |r| !r[:fields][field].to_s.empty? } or next
        value = row[:fields][field]
        fields[field] = value.is_a?(String) ? Address.text(value) : value
        provenance[field] = row[:source_id]
      end
    end

    def apply_optout
      @optout.refresh
      BoardModel.db.transaction do
        BoardModel.addresses.each { |r| BoardModel.set_optout(r[:id], @optout.level(r[:host], r[:ip])) }
      end
    end
  end
end
