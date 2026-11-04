# frozen_string_literal: true

require_relative '../../lib/domain'

module Discovery
  # What the tests of both faces share: listings, their pages and the parts
  # of BrowseService a face reads, on fixed data.
  module FaceFixtures
    NOW = Time.now.to_i

    # The parts of BrowseService the C64 face reads, on fixed listings.
    class Browse
      attr_reader :opened

      def initialize(listings, pages)
        @listings = listings
        @pages = pages
      end

      def search(_text, state: nil, **) = state ? @listings.select { |l| l.state == state } : @listings

      def tagged(_tag, state: nil, **) = search('', state: state)

      def all(state: nil, **) = search('', state: state)

      def axes(**) = BrowseService::AXES.except(:terminal)

      def facets(_axis, **) = [BrowseService::Facet.new(tag: 'sw:synchronet', label: 'Synchronet', count: 2)]

      def new_this_week(**) = []

      def recently_died(**) = []

      def graveyard(**) = []

      def random(**) = @listings.first

      def page(id) = @pages[id]

      def sources
        [{ id: 'tbg', record_count: 1060, last_parse_at: NOW - 3600, format: 'tbg_zip' },
         { id: 'sbl', record_count: 235, last_parse_at: NOW - 7200, format: 'sbl_html' },
         { id: 'fsxnet', record_count: 38, last_parse_at: NOW, last_error: 'HTTP 503' }]
      end

      def stats = { boards: 1359, online: 1090, petscii: 39, claimed: 232, shared: 341 }
    end

    def listing(name, state, country: 'us', tags: %w[petscii sw:synchronet])
      ListingModel.new(id: name, host: "#{name.downcase.tr(' ', '-')}.example.org", port: 64, name: name, state: state,
                       software: 'Synchronet', country: country, last_success_at: 1_000, first_probe_at: 1,
                       first_seen_at: 0, state_since: nil, tags: tags, optout: nil)
    end

    def page_of(listing, banner: "\x93HI".b, encoding: 'petscii')
      BoardPageModel.new(listing: listing,
                         board: { name: listing.name, provenance: '{}', sysop: 'Runstop' },
                         state: { last_success_at: NOW - 600, banner: banner, encoding: encoding,
                                  latency_ms: 87, country: listing.country },
                         sources: [{ source_id: 'cbbs', active: 1, name: 'CBBS Outpost' },
                                   { source_id: 'tbg', active: 1, name: 'Telnet BBS Guide' }],
                         probes: [{ at: NOW - 86_400, result: 'ok' }, { at: NOW, result: 'timeout' }])
    end

    # What a modern terminal shows after the bytes it got: the characters
    # of each row (the colours left out), for the looks of the modern face.
    class Terminal
      def initialize(cols = 80, rows = 24)
        @cols = cols
        @rows = rows
        @grid = Array.new(rows) { Array.new(cols, ' ') }
        @at = [0, 0]
      end

      def feed(text)
        text.to_s.dup.force_encoding(Encoding::UTF_8).scan(/\e\[([\d;?]*)([A-Za-z])|(.)/m) do |params, final, char|
          char ? put(char) : csi(params, final)
        end
        self
      end

      def lines = @grid.map { |row| row.join.rstrip }

      def to_s = lines.join("\n")

      private

      def put(char)
        return @at = [@at[0], 0] if char == "\r"
        return @at = [[@at[0] + 1, @rows - 1].min, @at[1]] if char == "\n"

        @grid[@at[0]][@at[1]] = char if @at[1] < @cols
        @at = [@at[0], @at[1] + 1]
      end

      def csi(params, final)
        case final
        when 'H' then @at = params.split(';').map { |n| [n.to_i - 1, 0].max }.then { |r, c| [r || 0, c || 0] }
        when 'K' then (@at[1]...@cols).each { |c| @grid[@at[0]][c] = ' ' }
        when 'J' then erase(params)
        end
      end

      def erase(params)
        rows = params == '2' ? (0...@rows) : ((@at[0] + 1)...@rows)
        (@at[1]...@cols).each { |c| @grid[@at[0]][c] = ' ' } unless params == '2'
        rows.each { |r| @grid[r] = Array.new(@cols, ' ') }
      end
    end
  end
end
