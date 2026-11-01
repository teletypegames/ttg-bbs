# frozen_string_literal: true

require_relative 'test_helper'
require 'bbs'
require_relative '../../lib/domain'
require_relative '../../lib/ui/petscii'

module Discovery
  # The C64 face: the frame, the sidebar, the views, and the bytes they cost.
  class C64Test < Minitest::Test
    Canvas = BBS::Petscii::Canvas
    Layout = UI::Petscii::Layout
    NOW = Time.now.to_i

    # The C64 line: what was sent, the keys to come.
    class Line
      attr_reader :sent

      def initialize(keys = [])
        @keys = keys
        @sent = []
      end

      def raw(bytes) = @sent << bytes.b

      def idle_limit = nil

      def session = nil

      def key(**) = @keys.shift || raise(IOError, 'done')

      def take
        bytes = @sent.join
        @sent.clear
        bytes
      end
    end

    # The parts of BrowseService the C64 face reads, on fixed listings.
    class Browse
      attr_reader :opened

      def initialize(listings, pages)
        @listings = listings
        @pages = pages
      end

      def search(_text, state: nil, **) = state ? @listings.select { |l| l.state == state } : @listings

      def tagged(_tag, state: nil, **) = search('', state: state)

      def axes(**) = BrowseService::AXES.except(:terminal)

      def facets(_axis, **) = [BrowseService::Facet.new(tag: 'sw:synchronet', label: 'Synchronet', count: 2)]

      def new_this_week(**) = []

      def recently_died(**) = []

      def graveyard(**) = []

      def random(**) = @listings.first

      def page(id) = @pages[id]

      def sources
        [{ 'id' => 'tbg', 'record_count' => 1060, 'last_parse_at' => NOW - 3600, 'format' => 'tbg_zip' },
         { 'id' => 'sbl', 'record_count' => 235, 'last_parse_at' => NOW - 7200, 'format' => 'sbl_html' },
         { 'id' => 'fsxnet', 'record_count' => 38, 'last_parse_at' => NOW, 'last_error' => 'HTTP 503' }]
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
                         board: { 'name' => listing.name, 'provenance' => '{}', 'sysop' => 'Runstop' },
                         state: { 'last_success_at' => NOW - 600, 'banner' => banner, 'encoding' => encoding,
                                  'latency_ms' => 87, 'country' => listing.country },
                         sources: [{ 'source_id' => 'cbbs', 'active' => 1, 'name' => 'CBBS Outpost' },
                                   { 'source_id' => 'tbg', 'active' => 1, 'name' => 'Telnet BBS Guide' }],
                         probes: [{ 'at' => NOW - 86_400, 'result' => 'ok' }, { 'at' => NOW, 'result' => 'timeout' }])
    end

    def own_boards(count = 10)
      Array.new(count) do |i|
        BoardModel.new({ 'id' => "b#{i}", 'name' => "Board #{i}", 'summary' => 'A board of the network, drawn in PETSCII.',
                         'tags' => %w[chat doors], 'port' => 2323 + i, 'accent' => '#3cff7a', 'petscii' => true },
                       host: 'gw', public_host: 'teletypegames.org')
      end
    end

    def gate(keys: [], listings: nil)
      listings ||= Array.new(20) { |i| listing(format('Board %02d', i), %w[online flaky down unknown][i % 4]) }
      @line = Line.new(keys)
      browse = Browse.new(listings, listings.to_h { |l| [l.id, page_of(l)] })
      UI::Petscii::Gate.new(@line, boards: own_boards, browse: browse, dials: nil, node: 2,
                                   clock: -> { Time.new(2026, 11, 1, 14, 52) })
    end

    # What the C64 shows after everything sent so far.
    def shown = (@shown ||= Canvas.new).feed(@line.take)

    def text_at(canvas, row, col, length) = (col...(col + length)).map { |c| canvas.cell(row, c).code.chr }.join

    def test_the_frame_has_the_logo_the_raster_the_sidebar_and_the_hint_bar
      g = gate
      g.start
      first = @line.sent.first
      assert_operator first.bytesize, :<=, 1300
      screen = shown
      logo = (1..8).map { |c| screen.cell(0, c) }
      assert_equal 'TTG GATE', logo.map { |c| c.code.chr }.join
      assert_equal [Canvas::RED, Canvas::ORANGE, Canvas::YELLOW], logo.first(3).map(&:color)
      assert(logo.first(3).all?(&:rvs))
      assert_equal 'NODE 2 14:52', text_at(screen, 0, 27, 12)
      assert_equal [Canvas::RED, Canvas::ORANGE], [screen.cell(1, 0).color, screen.cell(1, 4).color]
      assert_equal 0xa2, screen.cell(1, 0).code
      assert screen.cell(1, 0).rvs
      assert_equal 0xdd, screen.cell(5, Layout::DIVIDER).code
      own = screen.cell(2, 32)
      assert_equal ['O'.ord, Canvas::CYAN, true], [own.code, own.color, own.rvs]
      search = screen.cell(5, 32)
      assert_equal ['S'.ord, Canvas::YELLOW, false], [search.code, search.color, search.rvs]
      assert_equal 0xab, screen.cell(7, 31).code
      assert_equal 0xad, screen.cell(9, 31).code
      assert_equal '1359', text_at(screen, 17, 32, 4)
      assert_equal 'OWN SERVERS', text_at(screen, 2, 1, 11)
      assert_equal Canvas::YELLOW, screen.cell(2, 1).color
      assert_equal 'CRSR', text_at(screen, 24, 1, 4)
      assert_equal Canvas::YELLOW, screen.cell(24, 1).color
    end

    def test_own_servers_lights_a_row_and_a_step_is_a_patch
      g = gate
      g.start
      screen = shown
      lit = screen.cell(4, 0)
      assert_equal [Canvas::CYAN, true], [lit.color, lit.rvs]
      refute screen.cell(4, 3).rvs
      assert_equal UI::Petscii::Views::OwnView.color(own_boards[1]), screen.cell(5, 3).color
      assert_equal 'BOARD 0', text_at(screen, 16, 1, 7)
      g.press(:down)
      step = @line.sent.last
      assert_operator step.bytesize, :<=, 360
      refute_includes step.bytes, Canvas::CLEAR
      screen = shown
      assert screen.cell(5, 0).rvs
      refute screen.cell(4, 0).rvs
      assert_equal 'BOARD 1', text_at(screen, 16, 1, 7)
    end

    def test_the_sidebar_is_a_cursor_menu_and_the_hotkeys_work_from_anywhere
      g = gate
      g.start
      g.press(:left)
      assert_equal :side, g.focus
      g.press(:down)
      screen = shown
      assert screen.cell(3, 32).rvs
      refute screen.cell(2, 32).rvs
      g.press(:enter)
      assert_equal :main, g.focus
      assert_instance_of UI::Petscii::Views::ListView, g.view
      g.press('u')
      assert_instance_of UI::Petscii::Views::SourcesView, g.view
      g.press('w')
      assert_equal 'BY SOFTWARE', g.view.title
      g.press(:enter)
      assert_equal 2, g.stack.size
      g.press(:escape)
      assert_equal 1, g.stack.size
      g.press('h')
      assert_equal :help, g.view.section
      assert_equal :quit, g.press('q')
    end

    def test_the_discovery_list_marks_states_filters_and_steps_cheaply
      g = gate
      g.start
      g.press('d')
      first = @line.sent.last
      assert_operator first.bytesize, :<=, 1300
      screen = shown
      assert_equal 'PETSCII BOARDS', text_at(screen, 2, 1, 14)
      marks = (6..8).map { |r| screen.cell(r, 3) }
      assert_equal [0xd7, 0xd6, '?'.ord], marks.map(&:code)
      assert_equal [Canvas::YELLOW, Canvas::RED, Canvas::LIGHT_GREY], marks.map(&:color)
      assert_equal [Canvas::LIGHT_BLUE, true], [screen.cell(5, 0).color, screen.cell(5, 0).rvs]
      assert_equal 'NR S NAME', text_at(screen, 4, 0, 9)
      assert_equal 'ALIVE', text_at(screen, 3, 19, 5)
      g.press(:down)
      step = @line.sent.last
      assert_operator step.bytesize, :<=, 360
      assert_equal 'BOARD 01', text_at(shown, 15, 1, 8)
      g.press('f')
      assert_equal 'online', g.view.state
      assert_equal 5, g.view.items.size
      assert_equal 'ONLINE', text_at(shown, 3, 19, 6)
    end

    def test_a_board_page_has_the_strip_the_buttons_and_b_is_its_banner
      g = gate
      g.start
      g.press('d')
      g.press(:enter)
      page = g.view
      assert_instance_of UI::Petscii::Views::PageView, page
      assert_operator @line.sent.last.bytesize, :<=, 1300
      screen = shown
      assert_equal 'BOARD 00', text_at(screen, 2, 1, 8)
      assert_equal 'BOARD-00.EXAMPLE.ORG:64', text_at(screen, 4, 1, 23)
      strip = (0...30).map { |c| screen.cell(8, c) }
      assert_equal [Canvas::GREEN, Canvas::RED], strip.last(2).map(&:color)
      assert_equal Canvas::DARK_GREY, strip.first.color
      assert_equal 0xa6, strip.first.code
      assert_equal 'RETURN', text_at(screen, 18, 2, 6)
      assert_equal 'BANNER', text_at(screen, 18, 21, 6)
      assert_includes screen.to_s, 'SYSOP    RUNSTOP'
      assert_includes screen.to_s, 'CBBS/TBG'
      g.instance_variable_get(:@screen).instance_variable_set(:@keys, [' '])
      g.press('b')
      assert_same page, g.view
      assert_includes @line.sent.join, 'HI'
    end

    def test_only_petscii_banners_show_on_the_c64
      l = listing('Pub', 'online')
      ansi = UI::Petscii::Views::PageView.new(page_of(l, banner: "\e[2JHI".b, encoding: 'ansi'), section: :discover,
                                              on_dial: nil, on_banner: nil, now: -> { NOW })
      refute ansi.banner?
      canvas = Canvas.new
      ansi.draw(canvas)
      assert_includes canvas.to_s, 'ANSI BANNER: MODERN FACE'
      assert_equal :redraw, ansi.handle('b')
    end

    def test_the_sources_have_bars_their_state_and_the_petscii_count
      browse = Browse.new([], {})
      view = UI::Petscii::Views::SourcesView.new(browse.sources, browse.stats, now: -> { NOW })
      canvas = Canvas.new
      view.draw(canvas)
      text = canvas.to_s.lines
      assert_equal(14, (11..24).count { |c| canvas.cell(4, c).rvs })
      assert_includes text[4], 'TBG'
      assert_includes text[4], '1060'
      assert_includes text[5], 'MONTHLY ZIP/PERMISSION'
      assert_equal [Canvas::GREEN, true], [canvas.cell(5, 1).color, canvas.cell(5, 1).rvs]
      assert_includes text[9], 'HTTP 503'
      assert_includes text[19], 'BOARDS 1359  SHARED 341'
      assert_includes text[20], '39/232'
      assert_includes text[23], 'CC BY 4.0'
    end

    def test_the_patch_repaints_exactly_what_changed
      before = Canvas.new.text(3, 1, 'OLD TEXT', :green).text(10, 30, 'SIDE', :cyan)
      after = before.dup.text(3, 1, 'NEW', :white).text(12, 5, 'LOWER', :yellow, rvs: true).text(10, 39, 'X', :red)
      screen = Canvas.new.feed(before.frame)
      screen.feed(UI::Petscii::Diff.patch(after, after.changes(before)))
      assert_empty after.changes(screen)
    end
  end
end
