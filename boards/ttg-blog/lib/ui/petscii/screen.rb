# frozen_string_literal: true

module UI
  module Petscii
    # The Screen on a C64: the lists are menus of rubbs (BBS::Selector),
    # numbered as before, with a bar the cursor keys move.
    class Screen < UI::Screen
      # The colours of a menu: the bar in the title bar's cyan.
      MENU = { text: LG, key: YE, bar: CY, heading: DG, about: GR, hint: DG }.freeze

      # A numbered list of +items+ by +label+ under a title bar; the item
      # picked, or nil. CRSR and RETURN or the number pick; q, ← or
      # RUN/STOP go back.
      def pick(heading, items, empty: '(nothing here)', right: '', &label)
        return super if items.empty?

        title(heading, right)
        BBS::Selector.list(session, items, width: cols - 1, height: page_size, hint: 'crsr or number, return  q: back',
                                           exits: { 'q' => nil }, colors: MENU, &label)
      end

      # A menu of +items+ (BBS::Selector::Item) at the cursor: the value of
      # the one taken, +back+ for ← or RUN/STOP. The other options are those
      # of BBS::Selector.new.
      def menu(items, back: nil, **)
        BBS::Selector.new(session, items, width: cols - 1, back: back, colors: MENU, **).run
      end
    end
  end
end
