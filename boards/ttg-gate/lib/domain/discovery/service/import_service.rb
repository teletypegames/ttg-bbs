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

    # [catalog] a CatalogRepository   [config]  a ConfigRepository
    # [fetcher] a SourceFetcher       [tags]    a TagService
    # [aliases] an AliasService       [optout]  an OptoutRepository
    # [alert]   called with a message on a refused or failed source
    def initialize(catalog:, config:, fetcher:, tags:, aliases:, optout:, alert: ->(_) {})
      @catalog = catalog
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
      @catalog.set_meta('started_at', now) unless @catalog.meta('started_at')
      enabled = @config.sources.select(&:enabled?)
      @catalog.deactivate_other_sources(enabled.map(&:id))
      outcomes = enabled.select { |s| only.nil? || only.include?(s.id) }.map { |s| import(s, files[s.id], now) }
      resolve(now)
      @aliases.rebuild
      apply_optout
      @tags.refresh_all(now: now)
      @catalog.set_meta('last_import_at', now)
      outcomes
    end

    # Fetches, parses and applies one source.
    def import(source, file, now)
      records = records(source, file, now)
      previous = @catalog.source(source.id)['record_count'].to_i
      return refuse(source, records.size, previous, now) if previous.positive? && records.size < previous * KEEP

      @catalog.apply(source.id, records, now)
      @catalog.save_source(source, last_parse_at: now, record_count: records.size, last_error: nil)
      Outcome.new(source: source.id, status: :ok, records: records.size, message: nil)
    rescue SourceFetcher::FetchError, KeyError, SystemCallError, ArgumentError, EncodingError => e
      fail_source(source, "#{e.class}: #{e.message}", now)
    end

    private

    # The RecordModels of +source+, from +file+ when given, else fetched.
    def records(source, file, now)
      @catalog.save_source(source)
      bytes = file ? File.binread(file) : @fetcher.fetch(source)
      @catalog.save_source(source, last_fetch_at: now)
      Parsers.for(source.format).parse(bytes, source)
    end

    def refuse(source, count, previous, now)
      message = "#{source.name}: the parse gave #{count} records against #{previous} last time " \
                '(more than half lost); not applied, the old records stay'
      @catalog.save_source(source, last_error: message, last_error_at: now, refused_at: now)
      @alert.call(message)
      Outcome.new(source: source.id, status: :refused, records: count, message: message)
    end

    def fail_source(source, message, now)
      @catalog.save_source(source, last_error: message, last_error_at: now)
      @alert.call("#{source.name}: #{message}")
      Outcome.new(source: source.id, status: :failed, records: 0, message: message)
    end

    # The fields of every board from its active sources by priority (from all
    # it ever had when it is delisted), with their provenance.
    def resolve(now)
      rank = @config.priority.each_with_index.to_h
      @catalog.transaction { @catalog.board_ids.each { |id| resolve_board(id, rank, now) } }
    end

    def resolve_board(id, rank, now)
      rows = @catalog.board_sources(id)
      active = rows.select { |r| r['active'] == 1 }
      ranked = (active.empty? ? rows : active).sort_by { |r| [rank.fetch(r['source_id'], rank.size), -r['last_seen_at']] }
      @catalog.update_board(id, *best_fields(ranked), active.empty?, now)
    end

    # [the fields, the source of each] of +ranked+ source rows: each field
    # from the first row that has it, text cleaned again (Address.text), as
    # the rows of an older import may hold control characters.
    def best_fields(ranked)
      RecordModel::FIELDS.map(&:to_s).each_with_object([{}, {}]) do |field, (fields, provenance)|
        row = ranked.find { |r| !r['fields'][field].to_s.empty? } or next
        value = row['fields'][field]
        fields[field] = value.is_a?(String) ? Address.text(value) : value
        provenance[field] = row['source_id']
      end
    end

    def apply_optout
      @optout.refresh
      @catalog.transaction do
        @catalog.addresses.each { |r| @catalog.set_optout(r['id'], @optout.level(r['host'], r['ip'])) }
      end
    end
  end
end
