# frozen_string_literal: true

require 'json'

module Discovery
  # The tags of a board, all generated, from a closed vocabulary
  # (TTG_DISCOVERY.md §6.2):
  #
  # - encoding: ansi, petscii, atascii, ascii, measured only: the banner of
  #   the scheduled call, and of the C64-style call (both when they differ);
  # - claims:<encoding>: what a source-map rule reads from a source (the
  #   SyncTERM ScreenMode, a PETSCII comment, the CBBS Outpost's list). A
  #   claim is no encoding tag: it is not shown, only searched, and makes the
  #   prober call the board as a C64 (claims:petscii);
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
    CLAIMS = 'claims:'

    # [config] ConfigRepository: the sources, signatures and source-map rules
    def initialize(config)
      @config = config
    end

    # Writes the tags (and the search index row) of board +id+.
    def refresh(id, now: Time.now.to_i)
      board = BoardModel.where(id: id).naked.first
      return unless board

      TagModel.replace(id, tags(board, BoardSourceModel.of(id), BoardStateModel.of(id), now))
      BoardsFtsModel.index(id)
    end

    def refresh_all(now: Time.now.to_i) = BoardModel.ids.each { |id| refresh(id, now: now) }

    # The tags of +board+ (a boards row) with its board_sources rows and its
    # board_state row (or nil), all Hashes.
    def tags(board, sources, state, now)
      (listed_tags(board, sources, state) + called_tags(board, state || {}, now)).uniq.sort
    end

    private

    # What the lists and the banner tell: the sources, the encodings, the
    # software and the networks.
    def listed_tags(board, sources, state)
      software = software(board, state)
      [*sources.map { |s| "src:#{s[:source_id]}" }, *encodings(sources, state), software && "sw:#{software}",
       *networks(sources).map { |n| "net:#{n}" }].compact
    end

    # What our calls tell: the country, the state, new and veteran, the
    # telnet options.
    def called_tags(board, state, now)
      tags = []
      tags << "cc:#{state[:country]}" if state[:country]
      tags << state[:state] if STATES.include?(state[:state])
      tags << 'new' if new?(board, now)
      tags << 'veteran' if board[:since] && board[:since] < VETERAN_BEFORE
      tags + JSON.parse(state[:options] || '[]').filter_map { |o| OPTIONS[o.split.last] }
    end

    def encodings(sources, state)
      measured = [state&.dig(:encoding), state&.dig(:c64_encoding)] & ENCODINGS
      measured + mapped(:encoding, sources).map { |e| "#{CLAIMS}#{e}" }
    end

    def networks(sources)
      own = sources.filter_map { |s| @config.source(s[:source_id])&.network }
      own + mapped(:network, sources)
    end

    # The tags the source-map rules of +axis+ give the fields of +sources+.
    def mapped(axis, sources)
      @config.rules(axis).filter_map do |rule|
        values = sources.select { |s| s[:source_id] == rule.source }.flat_map { |s| Array(s[:fields][rule.field]) }
        rule.tag if values.any? { |v| v.to_s.match?(rule.pattern) }
      end
    end

    def software(board, state)
      return state[:software_id] if state&.dig(:software_id)

      BannerAnalyzer.software(board[:software], @config.signatures)&.id
    end

    def new?(board, now)
      started = MetaModel.value('started_at').to_i
      board[:first_seen_at] > started + DAY && now - board[:first_seen_at] < NEW_DAYS * DAY
    end
  end
end
