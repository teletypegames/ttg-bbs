# frozen_string_literal: true

require_relative 'layout'

module UI
  module Petscii
    # The frame around every screen of the C64 face: the menu bar (TTG
    # GATE, then OWN, GLOBAL and PROFILE, the active one lit), the active
    # place's line or sub-menu under it, and the hint bar at the bottom. The
    # sub-menu is a cursor menu: Item is one of its places, each with a
    # hotkey that works from anywhere.
    module Chrome
      # The menu bar's name of the board.
      TITLE = 'TTG GATE'
      # The colour of the menu bar (reversed cells).
      BAR = Canvas::CYAN
      # The colour of the active place on the bar.
      LIT = Canvas::PURPLE
      # The colour of the cell of a place's key on the bar.
      KEY = Canvas::YELLOW

      # A place of the menu bar: its +key+, +label+, the index of the letter
      # that opens it, and the column it starts at.
      Place = Data.define(:key, :label, :hotkey, :col) do
        def letter = label[hotkey].downcase
      end
      PLACES_BAR = [[:own, 'OWN'], [:discover, 'GLOBAL'], [:account, 'PROFILE']].each_with_object([]) do |(key, label), places|
        col = places.empty? ? TITLE.length + 4 : places.last.col + places.last.label.length + 3
        places << Place.new(key, label, 0, col)
      end.freeze

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
      # The keys that open a place from anywhere: the places of the bar (O,
      # G, P; D for Discovery and A for the account as before), the
      # sub-menu's yellow signs, the axes of Browse (soft_w_are, _c_ountry,
      # networ_k_), U for the Sources as before, Help and Quit.
      HOTKEYS = {
        'o' => :own,
        'd' => :discover,
        'g' => :discover,
        'w' => :software,
        'c' => :country,
        'k' => :network,
        'u' => :sources,
        'h' => :help,
        'a' => :account,
        'p' => :account,
        'q' => :quit
      }.merge(MENU.to_h { |i| [i.letter, i.key] }).freeze

      module_function

      # The menu bar on its row: cyan, TTG GATE, then each place with the
      # cell of its key in KEY; +active+ (a Place's key) in LIT.
      def bar(canvas, active:)
        canvas.text(Layout::BAR_ROW, 0, ' ' * Layout::WIDTH, BAR, rvs: true)
        canvas.text(Layout::BAR_ROW, 1, TITLE, BAR, rvs: true)
        PLACES_BAR.each do |place|
          color = place.key == active ? LIT : BAR
          canvas.text(Layout::BAR_ROW, place.col - 1, " #{place.label} ", color, rvs: true)
          canvas.text(Layout::BAR_ROW, place.col + place.hotkey, place.label[place.hotkey], KEY, rvs: true)
        end
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
        Layout.runs(
          canvas,
          Layout::HINT_ROW,
          1,
          parts.map { |t, k| [t, k ? Canvas::YELLOW : Canvas::WHITE] },
          limit: Layout::HINT_WIDTH
        )
      end
    end
  end
end
