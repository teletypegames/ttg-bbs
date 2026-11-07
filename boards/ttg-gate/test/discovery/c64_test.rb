# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'face_fixtures'
require 'rubbs'
require 'rubbs/test'
require_relative '../../lib/domain'
require_relative '../../lib/ui/petscii'

module Discovery
  # The C64 face: the frame, the tabs and the sub-menu, the views, and the
  # bytes they cost.
  class C64Test < Minitest::Test
    include FaceFixtures

    Canvas = UI::Petscii::Canvas
    Chrome = UI::Petscii::Chrome
    Layout = UI::Petscii::Layout

    def own_boards(count = 10)
      Array.new(count) do |i|
        ::BoardModel.new(
          {
            'id'      => "b#{i}",
            'name'    => "Board #{i}",
            'summary' => 'A board of the network, drawn in PETSCII.',
            'tags'    => %w[chat doors],
            'port'    => 2323 + i,
            'accent'  => '#3cff7a',
            'petscii' => true
          },
          host:        'gw',
          public_host: 'teletypegames.org'
        )
      end
    end

    def gate(keys: [], listings: nil)
      listings ||= Array.new(20) { |i| listing(format('Board %02d', i), %w[online flaky down unknown][i % 4]) }
      @line = Rubbs::Test::Session.new(keys: keys, petscii: true)
      browse = Browse.new(listings, listings.to_h { |l| [l.id, page_of(l)] })
      UI::Petscii::Gate.new(@line, boards: own_boards, browse: browse, dials: nil)
    end

    # What the C64 shows after everything sent so far.
    def shown = (@shown ||= Canvas.new).feed(@line.take)

    def canvas = Canvas.new(charset: :lower)

    def text_at(canvas, row, col, length) = canvas.to_s.lines[row].to_s.chomp.ljust(col + length)[col, length]

    def test_the_frame_has_the_menu_bar_the_own_line_and_the_hint_bar
      g = gate
      g.start
      first = @line.writes.first
      assert_operator first.bytesize, :<=, 1300
      assert_equal Canvas::LOWERCASE, first.getbyte(0)
      screen = shown
      assert_equal 'TTG GATE   OWN   GLOBAL   TODAY   YOU', text_at(screen, 0, 1, 37)
      assert((0..38).all? { |c| screen.cell(0, c).rvs })
      assert_equal Chrome::BAR, screen.cell(0, 1).color
      keys = Chrome::PLACES_BAR.map { |place| screen.cell(0, place.col) }
      assert_equal [Chrome::KEY], keys.map(&:color).uniq
      assert_equal([Chrome::LIT, Chrome::BAR, Chrome::BAR, Chrome::BAR], Chrome::PLACES_BAR.map { |place|
        screen.cell(0, place.col + 1).color
      })
      assert_equal '10 boards', text_at(screen, 1, 1, 9)
      assert_equal 'OWN SERVERS', text_at(screen, 3, 1, 11)
      assert_equal Canvas::YELLOW, screen.cell(3, 1).color
      assert_equal 'CRSR', text_at(screen, 24, 1, 4)
      assert_equal Canvas::YELLOW, screen.cell(24, 1).color
    end

    def test_global_lights_its_place_and_p_opens_the_profile
      g = gate
      g.start
      g.press('g')
      assert_equal([Chrome::BAR, Chrome::LIT], Chrome::PLACES_BAR.first(2).map { |place| shown.cell(0, place.col + 1).color })
      assert_equal :account, Chrome::HOTKEYS['p']
    end

    def test_own_servers_lights_a_row_and_a_step_is_a_patch
      g = gate
      g.start
      screen = shown
      lit = screen.cell(4, 0)
      assert_equal [Canvas::CYAN, true], [lit.color, lit.rvs]
      refute screen.cell(4, 3).rvs
      assert_equal UI::Petscii::Views::OwnView.color(own_boards[1]), screen.cell(5, 3).color
      assert_equal '2323', text_at(screen, 4, 35, 4)
      assert_equal 'Board 0', text_at(screen, 15, 1, 7)
      g.press(:down)
      step = @line.last
      assert_operator step.bytesize, :<=, 360
      refute_includes step.bytes, Canvas::CLEAR
      screen = shown
      assert screen.cell(5, 0).rvs
      refute screen.cell(4, 0).rvs
      assert_equal 'Board 1', text_at(screen, 15, 1, 7)
    end

    # D opens Browse; its second entry is All PETSCII.
    def all_petscii(gate)
      gate.press('d')
      gate.press(:down)
      gate.press(:enter)
    end

    def test_the_tabs_switch_and_the_sub_menu_is_a_cursor_menu
      g = gate
      g.start
      g.press(:up)
      assert_equal :bar, g.focus
      assert_equal Chrome::CURSOR, shown.cell(0, Chrome::PLACES_BAR[0].col + 1).color
      g.press(:right)
      assert_equal %i[discover bar], [g.tab, g.focus]
      g.press(:right)
      assert_equal :today, g.tab
      assert_equal Chrome::CURSOR, shown.cell(0, Chrome::PLACES_BAR[2].col + 1).color
      g.press(:left)
      g.press(:left)
      assert_equal %i[own bar], [g.tab, g.focus]
      g.press(:down)
      assert_equal :main, g.focus
      g.press('d')
      assert_equal :discover, g.tab
      assert_instance_of UI::Petscii::Views::MenuView, g.view
      screen = shown
      assert_equal '/Find Browse New Random Sources         ', text_at(screen, 1, 0, 40)
      assert_equal [Canvas::LIGHT_GREEN, true], [screen.cell(1, 6).color, screen.cell(1, 6).rvs]
      assert_equal Chrome::LIT, screen.cell(0, Chrome::PLACES_BAR[1].col + 1).color
      g.press(:down)
      g.press(:up)
      assert_equal :main, g.focus
      g.press(:up)
      assert_equal :menu, g.focus
      screen = shown
      assert_equal [Canvas::CYAN, true], [screen.cell(1, 6).color, screen.cell(1, 6).rvs]
      g.press(:down)
      assert_equal :main, g.focus
      g.press(:up)
      screen = shown
      assert screen.cell(1, 6).rvs
      refute screen.cell(1, 1).rvs
      g.press(:enter)
      assert_equal :main, g.focus
      assert_equal 'BROWSE', g.view.title
      screen = shown
      assert_equal [Canvas::LIGHT_GREEN, true], [screen.cell(1, 6).color, screen.cell(1, 6).rvs]
      g.press(:enter)
      assert_equal 2, g.stack.size
      g.press(:escape)
      assert_equal 1, g.stack.size
      g.press('s')
      assert_instance_of UI::Petscii::Views::SourcesView, g.view
      g.press('n')
      assert_equal :new, g.view.section
      g.press('u')
      assert_instance_of UI::Petscii::Views::SourcesView, g.view
      g.press('w')
      assert_equal 'BY SOFTWARE', g.view.title
      g.press('h')
      assert_equal :help, g.view.section
      assert_equal :discover, g.tab
      g.press('o')
      assert_equal :own, g.tab
      assert_equal '10 boards', text_at(shown, 1, 1, 9)
      assert g.press('q')
      assert_predicate g, :done?
    end

    def test_the_discovery_list_marks_states_filters_and_steps_cheaply
      g = gate
      g.start
      all_petscii(g)
      first = @line.last
      assert_operator first.bytesize, :<=, 1300
      screen = shown
      assert_equal 'ALL PETSCII', text_at(screen, 3, 1, 11)
      assert_equal '20  1/2', text_at(screen, 3, 32, 7)
      marks = (7..9).map { |r| screen.cell(r, 3) }
      assert_equal [0xa1] * 3, marks.map(&:code)
      assert_equal [Canvas::YELLOW, Canvas::RED, Canvas::DARK_GREY], marks.map(&:color)
      assert_equal [Canvas::LIGHT_BLUE, true], [screen.cell(6, 0).color, screen.cell(6, 0).rvs]
      assert_equal [Canvas::LIGHT_BLUE, true], [screen.cell(6, 39).color, screen.cell(6, 39).rvs]
      assert_equal 'Nr S Name', text_at(screen, 5, 0, 9)
      assert_equal 'US Synchronet', text_at(screen, 7, 26, 13)
      assert_equal 'Board 09', text_at(screen, 15, 5, 8)
      assert_equal 'All', text_at(screen, 4, 19, 3)
      g.press(:down)
      step = @line.last
      assert_operator step.bytesize, :<=, 360
      assert_equal 'Board 01', text_at(shown, 17, 1, 8)
      g.press('f')
      assert_equal 'online', g.view.state
      assert_equal 5, g.view.items.size
      assert_equal 'Online', text_at(shown, 4, 19, 6)
    end

    def test_a_board_page_has_the_strip_the_buttons_and_b_is_its_banner
      g = gate
      g.start
      all_petscii(g)
      g.press(:enter)
      page = g.view
      assert_instance_of UI::Petscii::Views::PageView, page
      assert_operator @line.last.bytesize, :<=, 1300
      screen = shown
      assert_equal 'Board 00', text_at(screen, 3, 1, 8)
      assert_equal 'board-00.example.org:64', text_at(screen, 4, 1, 23)
      strip = (1..30).map { |c| screen.cell(8, c) }
      assert_equal [Canvas::GREEN, Canvas::RED], strip.last(2).map(&:color)
      assert_equal Canvas::DARK_GREY, strip.first.color
      assert_equal 0xa6, strip.first.code
      assert_equal 'RETURN', text_at(screen, 21, 2, 6)
      assert_equal 'Banner', text_at(screen, 21, 21, 6)
      assert_includes screen.to_s, 'Sysop    Runstop'
      assert_includes screen.to_s, 'CBBS/TBG'
      @line.keys << ' '
      g.press('b')
      assert_same page, g.view
      assert_includes @line.raw, 'HI'
    end

    def test_a_long_address_wraps_whole_and_pushes_the_page_down
      host = 'a-very-long-hostname-of-a-board.bbs.example.org'
      l = ListingModel.new(
        id:              'x',
        host:            host,
        port:            6400,
        name:            'Long',
        state:           'online',
        software:        'Synchronet',
        country:         'us',
        last_success_at: 1_000,
        first_probe_at:  1,
        first_seen_at:   0,
        state_since:     nil,
        tags:            %w[petscii],
        optout:          nil
      )
      view = UI::Petscii::Views::PageView.new(page_of(l), section: :discover, on_dial: nil, on_banner: nil, now: -> { NOW })
      canvas = self.canvas
      view.draw(canvas)
      lines = canvas.to_s.lines.map { |line| line[0, Layout::WIDTH].strip }
      assert_equal "#{host}:6400", lines[4] + lines[5]
      assert_equal 'a-very-long-hostname-of-a-board.bbs.', lines[4]
      assert_includes canvas.to_s, 'wiki.teletypegames.org'
      list = gate(listings: [l])
      list.start
      all_petscii(list)
      text = shown.to_s.lines.map { |line| line[0, Layout::WIDTH].strip }
      assert_includes text.each_cons(2).map { |a, b| a + b }, "#{host}:6400"
    end

    def test_only_petscii_banners_show_on_the_c64
      l = listing('Pub', 'online')
      ansi = UI::Petscii::Views::PageView.new(
        page_of(l, banner: "\e[2JHI".b, encoding: 'ansi'),
        section:   :discover,
        on_dial:   nil,
        on_banner: nil,
        now:       -> { NOW }
      )
      refute ansi.banner?
      canvas = self.canvas
      ansi.draw(canvas)
      assert_includes canvas.to_s, 'ANSI banner: modern face'
      assert ansi.handle('b')
    end

    def test_the_sources_have_bars_their_state_and_the_petscii_count
      browse = Browse.new([], {})
      view = UI::Petscii::Views::SourcesView.new(browse.sources, browse.stats, now: -> { NOW })
      canvas = self.canvas
      view.draw(canvas)
      text = canvas.to_s.lines
      assert_equal(21, (11..38).count { |c| canvas.cell(4, c).rvs })
      assert_includes text[4], 'TBG'
      assert_includes text[4], '1060'
      assert_includes text[5], 'monthly ZIP/permission'
      assert_equal [Canvas::GREEN, true], [canvas.cell(5, 1).color, canvas.cell(5, 1).rvs]
      assert_includes text[9], 'HTTP 503'
      assert_includes text[19], 'Boards 1359  shared 341'
      assert_includes text[20], '39/232'
      assert_includes text[23], 'CC BY 4.0'
    end

    def test_the_hint_row_reads_the_search_and_its_list_opens
      g = gate(keys: ['s', 'y', 'n', :backspace, :enter])
      g.start
      g.press('/')
      assert_equal :search, g.view.section
      assert_equal 'FIND sy', g.view.title
      screens = @line.writes.each_with_object([Canvas.new]) { |w, all| all << all.last.dup.feed(w) }
      assert(screens.any? { |screen| text_at(screen, 24, 0, 9) == 'Find: syn' })
      assert(screens.any? { |screen| text_at(screen, 24, 0, 8) == 'Find: sy' && screen.cell(24, 8).rvs })
    end
  end
end
