# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'face_fixtures'
require_relative '../../lib/domain'
require 'rubbs/test'
require_relative '../../lib/ui/modern'

module Discovery
  # The modern face: what a third-party list says reaches the screen without
  # a control character, and our own boards' menu.
  class ModernTest < Minitest::Test
    include FaceFixtures

    # A screen of the modern face.
    class Screen
      include UI::Modern::Style

      attr_reader :session

      def initialize(session) = @session = session
    end

    def session(keys = []) = Rubbs::Test::Session.new(keys: keys)

    def screen = Screen.new(session)

    def test_fit_lets_no_control_character_through
      text = screen.fit("Evil\e[2J‮\u0085 BBS", 20)
      assert_equal 'Evil[2J BBS'.ljust(20), text
      assert_equal 'Long name…', screen.fit("Long name\e[31m of a board", 10)
    end

    def test_crumbs_clean_both_sides
      line = screen.crumbs("SEARCH \e]0;x\a", "host\e[2J:23")
      refute_includes line.gsub(/\e\[[\d;]*m/, ''), "\e"
      assert_includes line, 'host[2J:23'
    end

    def boards
      BoardRepository.new(File.join(Root::ROOT, 'config/boards.yml'), host: 'localhost', public_host: 'example.org').all
    end

    # The parts of TTGGateBBS the modern face reads; no catalog.
    Bbs = Struct.new(:directory, :browse, :dials, :accounts)
    Directory = Struct.new(:all) { def boards(**) = DirectoryService.new(self).boards(**) }

    def gate(keys) = UI::Modern::Gate.new(@line = session(keys), Bbs.new(Directory.new(boards), nil, nil))

    def test_own_servers_hang_up_and_switch
      assert_nil gate(['q']).run
      assert_includes @line.output, 'OWN SERVERS'
      g = gate([:tab])
      assert_raises(Rubbs::Common::Line::Hangup) { g.run }
      assert_instance_of UI::Modern::Discovery::Home, g.page
      assert_includes @line.output, 'Global Discovery is resting'
      assert_nil gate([:tab, :tab, :down, 'Q']).run
    end

    def test_own_servers_dial_hands_the_line_over
      dialled = []
      UI.stub(:dial, ->(_session, board) { dialled << board.name }) do
        assert_nil gate(%w[2 q]).run
      end
      assert_equal [boards[1].name], dialled
      assert_includes @line.output, Rubbs::Common::Screens::Pages::MODERN_RESTORE
    end

    def test_the_selector_of_rubbs_is_not_shadowed
      refute UI::Modern.const_defined?(:Selector, false)
    end

    def discovery(keys)
      listings = Array.new(30) { |i| listing(format('Board %02d', i), %w[online flaky down unknown][i % 4]) }
      browse = Browse.new(listings, listings.to_h { |l| [l.id, page_of(l, banner: "\e[1;33mHELLO".b, encoding: 'ansi')] })
      UI::Modern::Gate.new(@line = session(keys), Bbs.new(Directory.new(boards), browse, nil))
    end

    # TAB to Global Discovery, / search, its list, a board's page and its
    # banner, back to the list and back home.
    def test_discovery_searches_lists_and_opens_a_board
      g = discovery([:tab, '/', 's', 'y', :backspace, 'x', :enter, :down, :enter, 'b', ' ', 'q', :page_down])
      assert_raises(Rubbs::Common::Line::Hangup) { g.run }
      assert_includes Terminal.new.feed(@line.output).to_s, 'page 2/2'
      @line.keys.push('q', 'q')
      assert_nil g.run
      out = @line.output
      assert_includes out, 'Search:'
      assert_includes out, "\e[?25h"
      assert_includes out, 'SEARCH “sx”'
      assert_includes out, 'Board 01'
      assert_includes out, "\e[1;33mHELLO"
      assert_includes out, 'The banner of Board 01'
      assert_instance_of UI::Modern::Discovery::Home, g.page
    end

    def test_the_prompt_gives_up_on_escape
      g = discovery([:tab, '/', 'a', :escape, :down, :down, :enter, 'q', 'q'])
      assert_nil g.run
      refute_includes @line.output, 'SEARCH “a”'
      assert_includes @line.output, 'BROWSE'
    end
  end
end
