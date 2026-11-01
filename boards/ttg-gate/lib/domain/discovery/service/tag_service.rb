# frozen_string_literal: true

require 'json'

module Discovery
  # The tags of a board, all generated, from a closed vocabulary
  # (TTG_DISCOVERY.md §6.2):
  #
  # - encoding: ansi, petscii, atascii, ascii, from the banner, plus what a
  #   source-map rule reads from a source (both when they differ);
  # - sw:<id>: the software signature of the banner, else of the source's
  #   software field;
  # - net:<network>: the nodelists that list it, and source-map rules;
  # - cc:<country>: its IP's country (DB-IP);
  # - online, flaky, down, dead: its state;
  # - new (first seen < 14 days ago, not in the first import), veteran (on
  #   line before 1995 by a source);
  # - binary, naws, ttype: the telnet options it asked for or offered;
  # - src:<source>: the sources that list it (or listed it).
  class TagService
    DAY = 86_400
    NEW_DAYS = 14
    VETERAN_BEFORE = 1995
    ENCODINGS = %w[ansi petscii atascii ascii].freeze
    OPTIONS = { 'BINARY' => 'binary', 'NAWS' => 'naws', 'TTYPE' => 'ttype' }.freeze
    STATES = %w[online flaky down dead].freeze

    def initialize(catalog, probes, config)
      @catalog = catalog
      @probes  = probes
      @config  = config
    end

    # Writes the tags (and the search index row) of board +id+.
    def refresh(id, now: Time.now.to_i)
      board = @catalog.board(id)
      return unless board

      @catalog.replace_tags(id, tags(board, @catalog.board_sources(id), @probes.state(id), now))
      @catalog.index(id)
    end

    def refresh_all(now: Time.now.to_i) = @catalog.board_ids.each { |id| refresh(id, now: now) }

    # The tags of +board+ (a boards row) with its board_sources rows and its
    # board_state row (or nil).
    def tags(board, sources, state, now)
      tags = sources.map { |s| "src:#{s['source_id']}" }
      tags += encodings(sources, state)
      tags << "sw:#{software(board, state)}" if software(board, state)
      tags += networks(sources).map { |n| "net:#{n}" }
      tags << "cc:#{state['country']}" if state&.dig('country')
      tags << state['state'] if state && STATES.include?(state['state'])
      tags << 'new' if new?(board, now)
      tags << 'veteran' if board['since'] && board['since'] < VETERAN_BEFORE
      tags += JSON.parse(state&.dig('options') || '[]').filter_map { |o| OPTIONS[o.split.last] }
      tags.uniq.sort
    end

    private

    def encodings(sources, state)
      from_banner = [state&.dig('encoding')] & ENCODINGS
      from_banner + mapped(:encoding, sources)
    end

    def networks(sources)
      own = sources.filter_map { |s| @config.source(s['source_id'])&.network }
      own + mapped(:network, sources)
    end

    # The tags the source-map rules of +axis+ give the fields of +sources+.
    def mapped(axis, sources)
      @config.rules(axis).filter_map do |rule|
        values = sources.select { |s| s['source_id'] == rule.source }.flat_map { |s| Array(s['fields'][rule.field]) }
        rule.tag if values.any? { |v| v.to_s.match?(rule.pattern) }
      end
    end

    def software(board, state)
      return state['software_id'] if state&.dig('software_id')

      BannerAnalyzer.software(board['software'], @config.signatures)&.id
    end

    def new?(board, now)
      started = @catalog.meta('started_at').to_i
      board['first_seen_at'] > started + DAY && now - board['first_seen_at'] < NEW_DAYS * DAY
    end
  end
end
