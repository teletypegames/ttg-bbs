# frozen_string_literal: true

require_relative 'layout'

module UI
  module Petscii
    # The frame around every screen of the C64 face: the header (the colour
    # logo, the node and the clock), the two tabs (Own Servers, Global
    # Discovery), the active tab's sub-menu under them and the hint bar at
    # the bottom. The sub-menu is a cursor menu: Item is one of its places,
    # each with a hotkey that works from anywhere.
    module Chrome
      LOGO = [['T', Canvas::RED], ['T', Canvas::ORANGE], ['G', Canvas::YELLOW], [' ', nil],
              ['G', Canvas::LIGHT_GREEN], ['A', Canvas::CYAN], ['T', Canvas::LIGHT_BLUE], ['E', Canvas::PURPLE]].freeze

      # A tab: its +key+, +label+, its +color+ and the column it starts at.
      Tab = Data.define(:key, :label, :color, :col)
      TABS = [Tab.new(:own, 'OWN SERVERS', Canvas::YELLOW, 1),
              Tab.new(:discover, 'GLOBAL DISCOVERY', Canvas::LIGHT_GREEN, 15)].freeze

      # A place of the sub-menu of Global Discovery: +key+ the section it
      # opens, +label+, the index of its +hotkey+ sign in the label, and the
      # column it starts at.
      Item = Data.define(:key, :label, :hotkey, :col) do
        def letter = label[hotkey].downcase
      end

      PLACES = [[:search, '/Find', 0], [:browse, 'Browse', 0], [:new, 'New', 0], [:random, 'Random', 0],
                [:died, 'Died', 2], [:graves, 'Graves', 0], [:sources, 'Srcs', 0]].freeze
      MENU = PLACES.each_with_object([]) do |(key, label, hotkey), items|
        col = items.empty? ? 0 : items.last.col + items.last.label.length + 1
        items << Item.new(key, label, hotkey, col)
      end.freeze
      # The sections that light a place of the sub-menu other than their own.
      UNDER = { all: :browse, software: :browse, country: :browse, network: :browse }.freeze
      # The keys that open a place from anywhere: the tabs, the sub-menu's
      # yellow signs, the axes of Browse (soft_w_are, _c_ountry, networ_k_),
      # U for the Sources as before, Help and Quit.
      HOTKEYS = { 'o' => :own, 'd' => :discover, 'w' => :software, 'c' => :country, 'k' => :network,
                  'u' => :sources, 'h' => :help, 'q' => :quit }.merge(MENU.to_h { |i| [i.letter, i.key] }).freeze

      module_function

      # The header: the logo, the node and the clock.
      def header(canvas, node:, time:)
        LOGO.each_with_index do |(ch, color), i|
          canvas.text(Layout::HEADER_ROW, 1 + i, ch, color, rvs: true) if color
        end
        canvas.text(Layout::HEADER_ROW, 9, ' BBS', Canvas::WHITE)
        clock(canvas, node: node, time: time)
      end

      def clock(canvas, node:, time:)
        node = "Node #{node}"
        canvas.text(Layout::HEADER_ROW, 33 - node.length, node, Canvas::GREY)
        canvas.text(Layout::HEADER_ROW, 34, time.strftime('%H:%M'), Canvas::CYAN)
      end

      # The tabs, +active+ a band in its colour, the other dim with its
      # yellow letter, and the boards online of +stats+ on the right.
      def tabs(canvas, active:, stats:)
        TABS.each do |tab|
          if tab.key == active
            canvas.text(Layout::TABS_ROW, tab.col - 1, " #{tab.label} ", tab.color, rvs: true)
          else
            canvas.text(Layout::TABS_ROW, tab.col, tab.label, Canvas::GREY)
            canvas.text(Layout::TABS_ROW, tab.col, tab.label[0], Canvas::YELLOW)
          end
        end
        online = stats && stats[:online]
        return unless online

        count = online.to_s
        canvas.text(Layout::TABS_ROW, Layout::EDGE - count.length - 1, '▌', Canvas::LIGHT_GREEN)
        canvas.text(Layout::TABS_ROW, Layout::EDGE - count.length, count, Canvas::WHITE)
      end

      # The sub-menu of Global Discovery: +lit+ (an Item's key) a reversed
      # bar, cyan while the menu has the focus (+focused+), light green
      # otherwise.
      def menu(canvas, lit:, focused:)
        MENU.each do |item|
          if item.key == lit
            canvas.text(Layout::MENU_ROW, item.col, item.label, focused ? Canvas::CYAN : Canvas::LIGHT_GREEN, rvs: true)
          else
            canvas.text(Layout::MENU_ROW, item.col, item.label, Canvas::LIGHT_GREY)
            canvas.text(Layout::MENU_ROW, item.col + item.hotkey, item.label[item.hotkey], Canvas::YELLOW)
          end
        end
      end

      # The line under the tabs on Own Servers: how many boards, and how.
      def own_line(canvas, count)
        Layout.runs(canvas, Layout::MENU_ROW, 1, [[count.to_s, Canvas::WHITE], [' boards  ', Canvas::GREY],
                                                  ['RETURN', Canvas::YELLOW], [' dials  ', Canvas::GREY],
                                                  ['H', Canvas::YELLOW], [' Help', Canvas::GREY]])
      end

      # The hint bar: +parts+ of [text, key?], the keys yellow, the words
      # white.
      def hint(canvas, parts)
        Layout.runs(canvas, Layout::HINT_ROW, 1, parts.map { |t, k| [t, k ? Canvas::YELLOW : Canvas::WHITE] },
                    limit: Layout::HINT_WIDTH)
      end
    end
  end
end
