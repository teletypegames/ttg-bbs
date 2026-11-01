# frozen_string_literal: true

require_relative 'layout'

module UI
  module Petscii
    # The frame around every screen of the C64 face: the header (the colour
    # logo, the rest of the row in HEADER), the two tabs in one colour (TAB) (Own Servers, Global
    # Discovery), the active tab's sub-menu under them and the hint bar at
    # the bottom. The sub-menu is a cursor menu: Item is one of its places,
    # each with a hotkey that works from anywhere.
    module Chrome
      LOGO = [['T', Canvas::RED], ['T', Canvas::ORANGE], ['G', Canvas::YELLOW], [' ', nil],
              ['G', Canvas::LIGHT_GREEN], ['A', Canvas::CYAN], ['T', Canvas::LIGHT_BLUE], ['E', Canvas::PURPLE]].freeze

      # The colour of the header row but the logo: BBS, the node, the clock.
      HEADER = Canvas::LIGHT_GREY
      # The one colour of the tab switch: the active tab a band in it, the
      # other its plain letters, and the boards online on the right.
      TAB = Canvas::CYAN

      # A tab: its +key+, +label+ and the column it starts at.
      Tab = Data.define(:key, :label, :col)
      TABS = [Tab.new(:own, 'OWN SERVERS', 1), Tab.new(:discover, 'GLOBAL DISCOVERY', 15)].freeze

      # A place of the sub-menu of Global Discovery: +key+ the section it
      # opens, +label+, the index of its +hotkey+ sign in the label, and the
      # column it starts at.
      Item = Data.define(:key, :label, :hotkey, :col) do
        def letter = label[hotkey].downcase
      end

      PLACES = [[:search, '/Find', 0], [:browse, 'Browse', 0], [:new, 'New', 0], [:random, 'Random', 0],
                [:sources, 'Sources', 0]].freeze
      MENU = PLACES.each_with_object([]) do |(key, label, hotkey), items|
        col = items.empty? ? 0 : items.last.col + items.last.label.length + 1
        items << Item.new(key, label, hotkey, col)
      end.freeze
      # The sections that light a place of the sub-menu other than their own.
      UNDER = { all: :browse, software: :browse, country: :browse, network: :browse }.freeze
      # The keys that open a place from anywhere: the tabs (G as in Global
      # Discovery too), the sub-menu's yellow signs, the axes of Browse
      # (soft_w_are, _c_ountry, networ_k_), U for the Sources as before, Help and Quit.
      HOTKEYS = { 'o' => :own, 'd' => :discover, 'g' => :discover, 'w' => :software, 'c' => :country, 'k' => :network,
                  'u' => :sources, 'h' => :help, 'q' => :quit }.merge(MENU.to_h { |i| [i.letter, i.key] }).freeze

      module_function

      # The header: the logo, the node and the clock.
      def header(canvas, node:, time:)
        LOGO.each_with_index do |(ch, color), i|
          canvas.text(Layout::HEADER_ROW, 1 + i, ch, color, rvs: true) if color
        end
        canvas.text(Layout::HEADER_ROW, 9, ' BBS', HEADER)
        clock(canvas, node: node, time: time)
      end

      def clock(canvas, node:, time:)
        node = "Node #{node}"
        canvas.text(Layout::HEADER_ROW, 33 - node.length, node, HEADER)
        canvas.text(Layout::HEADER_ROW, 34, time.strftime('%H:%M'), HEADER)
      end

      # The tabs in TAB, +active+ a band, and the boards online of +stats+
      # on the right.
      def tabs(canvas, active:, stats:)
        TABS.each do |tab|
          if tab.key == active
            canvas.text(Layout::TABS_ROW, tab.col - 1, " #{tab.label} ", TAB, rvs: true)
          else
            canvas.text(Layout::TABS_ROW, tab.col, tab.label, TAB)
          end
        end
        online = stats && stats[:online]
        return unless online

        count = "▌#{online}"
        canvas.text(Layout::TABS_ROW, Layout::EDGE - count.length, count, TAB)
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
