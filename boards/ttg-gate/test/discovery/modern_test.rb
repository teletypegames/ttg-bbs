# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../../lib/domain'
require_relative '../../lib/ui/modern'

module Discovery
  # The modern face: what a third-party list says reaches the screen without
  # a control character, and our own boards' menu.
  class ModernTest < Minitest::Test
    # A caller's line: what was written, the keys to come.
    class Session
      attr_reader :out

      def initialize(keys = [])
        @keys = keys
        @out  = +''
      end

      def write(text) = @out << text
      def readkey(**) = @keys.shift
      def term_cols = 80
      def term_rows = 24
      def session_id = 'test'
    end

    # A screen of the modern face.
    class Screen
      include UI::Modern::Style

      def initialize(session) = @session = session
    end

    def screen = Screen.new(Session.new)

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

    def test_own_servers_hang_up_and_switch
      assert_nil UI::Modern::OwnServers.new(Session.new(['q']), boards).run
      assert_equal :switch, UI::Modern::OwnServers.new(Session.new([:tab]), boards).run
      assert_raises(IOError) { UI::Modern::OwnServers.new(Session.new, boards).run }
    end

    def test_the_selector_of_rubbs_is_not_shadowed
      refute UI::Modern.const_defined?(:Selector, false)
    end
  end
end
