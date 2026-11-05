# frozen_string_literal: true

require_relative 'chrome'
require_relative 'views/picker'
require_relative 'views/own_view'
require_relative 'views/list_view'
require_relative 'views/menu_view'
require_relative 'views/page_view'
require_relative 'views/sources_view'
require_relative 'views/text_view'
require_relative 'gate/places'
require_relative 'gate/dialing'
require_relative 'gate/input'

module UI
  module Petscii
    # One C64 call of the gate: the frame (Chrome) around a view of the
    # content, the tabs (OWN, GLOBAL, PROFILE) and the active one's
    # sub-menu above it. O, D and P open them from anywhere. CRSR up from
    # the top of a list (or from a page) moves the focus up: on Global
    # Discovery to the sub-menu, and from there (or on Own Servers at once)
    # to the tabs. On the tabs CRSR left and right switch between OWN and
    # GLOBAL as the cursor goes, PROFILE opens on RETURN; on the sub-menu
    # CRSR left and right move its bar and RETURN opens. CRSR down goes
    # back to the content. A yellow sign of the sub-menu opens its place from
    # anywhere (a view's own keys first: B on a board's page is its banner).
    # ← or RUN/STOP goes back, Q hangs up.
    #
    # The views are the pages of a BBS::Pages runner: each change is drawn
    # on a new Canvas and only the cells that differ from what the C64
    # shows go out, or the whole screen when that is shorter.
    class Gate < BBS::Pages
      include Places
      include Dialing
      include Input

      # Seconds between two steps of the dialling.
      STEP = 0.12
      INPUT_LABEL = 'Find:'
      INPUT_MAX   = Layout::HINT_WIDTH - INPUT_LABEL.length - 2
      MENU_HINT   = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Open  ', false], ['CRSR down', true],
                     [' List', false]].freeze
      # The keys the tabs and the sub-menu take while they have the focus.
      FOCUS_KEYS  = %i[left right up down enter].freeze
      BAR_HINT    = [['CRSR', true], [' Tabs  ', false], ['RETURN', true], [' Open  ', false], ['CRSR down', true],
                     [' Back', false]].freeze
      WARNINGS = { dead: ['This board has not answered', 'our calls for 30 days.', 'It may be gone. Dial anyway?'] }.freeze
      REFUSALS = {
        rate:        ['You dialled 10 boards in', '10 minutes. Try again later.'],
        busy:        ['3 callers are on this board', 'already. Try again soon.'],
        not_petscii: ['This board speaks neither', 'PETSCII nor plain ASCII.'],
        not_public:  ['This board is not on the', 'public internet.'],
        unknown:     ['This board is gone from the list.']
      }.freeze
      # The lists of their own: the title, the chip, its colour, the words of
      # an empty one, the BrowseService method.
      FIXED = {
        new:    ['NEW THIS WEEK', '7 days', Canvas::LIGHT_GREY, 'No new board this week.', :new_this_week],
        died:   ['RECENTLY DIED', '30 days', Canvas::LIGHT_RED, 'None died in 30 days.', :recently_died],
        graves: ['GRAVEYARD', 'dead', Canvas::GREY, 'No graves yet.', :graveyard]
      }.freeze
      BANDS = {
        discover: Canvas::LIGHT_GREEN,
        all:      Canvas::LIGHT_GREEN,
        search:   Canvas::WHITE,
        browse:   Canvas::ORANGE,
        new:      Canvas::PURPLE,
        died:     Canvas::LIGHT_RED,
        graves:   Canvas::GREY
      }.freeze

      attr_reader :focus, :tab

      # [session] the C64 line
      # [boards] our boards with a C64 face (BoardModel)
      # [browse] Discovery::BrowseService, nil without a catalog
      # [dials]  Discovery::DialService
      def initialize(session, boards:, browse:, dials:)
        super(session, face: :petscii, charset: :lower)
        @boards = boards
        @browse = browse
        @dials  = dials
        @focus  = :main
        @tab    = :own
        @menu   = 0
        @bar    = 0
        @status = nil
      end

      # Runs the call until the caller hangs up (Q, or RUN/STOP on our own
      # boards) or idles too long.
      def run = super(own)

      # The first screen: our own boards.
      def start(page = own)
        @section = :own
        @tab = :own
        super
      end

      def view = page

      # Answers one key: the sub-menu while it has the focus, CRSR up to it,
      # RUN/STOP back, then the view's own keys, then the hotkeys.
      def handle(key)
        return focus_key(key) || true if @focus != :main && FOCUS_KEYS.include?(key)
        return climb || true if key == :up && climb?
        return back || true if key == :escape

        view.handle(key) || hotkey(key)
      end

      # The screen as it is now: the frame around the view, the search line
      # or the hint bar, the cursor resting at the end of the hint row.
      def draw(canvas)
        Chrome.bar(canvas, active: @tab == :own ? :own : :discover, cursor: (bar_place.key if @focus == :bar))
        if @tab == :own
          Chrome.own_line(canvas, @boards.size)
        else
          Chrome.menu(canvas, lit: lit, focused: @focus == :menu)
        end
        view.draw(canvas)
        if line
          input_line(canvas)
        else
          Chrome.hint(canvas, hint)
        end
        cursor(Layout::HINT_ROW, Layout::HINT_WIDTH)
      end

      # Over another view: the focus back on the content.
      def push(target)
        @focus = :main
        super
      end

      # Back a screen; from a section's first one to our own boards, and from
      # there the call ends.
      def back
        @focus = :main
        return super if stack.size > 1
        return quit if @section == :own

        go(:own)
      end

      private

      def hint = @status || { menu: MENU_HINT, bar: BAR_HINT }.fetch(@focus) { view.hint }

      def bar_place = Chrome::PLACES_BAR[@bar]

      def focus_key(key) = @focus == :bar ? bar_key(key) : menu_key(key)

      def climb? = to_menu? || to_bar?

      # CRSR up from the content: the sub-menu, or the tabs.
      def climb = to_menu? ? to_menu : to_bar

      # CRSR up goes to the tabs on Own Servers from the top of the list (on
      # Global Discovery the sub-menu is between, see #menu_key).
      def to_bar?
        return false unless @tab == :own && @focus == :main

        !view.is_a?(Views::Picker) || view.at_top?
      end

      def to_bar
        @bar = Chrome::PLACES_BAR.index { |p| p.key == (@tab == :own ? :own : :discover) } || 0
        @focus = :bar
      end

      # The tabs: left and right switch OWN and GLOBAL as the cursor goes
      # (PROFILE waits for RETURN), RETURN opens, down goes back.
      def bar_key(key)
        case key
        when :left, :right
          @bar = (@bar + (key == :left ? -1 : 1)) % Chrome::PLACES_BAR.size
          follow_bar
        when :down then @focus = :main
        when :enter then go(bar_place.key)
        end
      end

      def follow_bar
        place = bar_place.key
        return if [:account, (@tab == :own ? :own : :discover)].include?(place)

        go(place)
        @focus = :bar
      end

      # The place of the sub-menu lit: the cursor's while the menu has the
      # focus, else the section's (Browse for its axes).
      def lit
        return Chrome::MENU[@menu].key if @focus == :menu

        section = view.section || @section
        Chrome::UNDER.fetch(section, section)
      end

      # CRSR up goes to the sub-menu on Global Discovery from the top of a
      # list, or from a screen without one.
      def to_menu?
        return false unless @tab == :discover && @focus == :main

        !view.is_a?(Views::Picker) || view.at_top?
      end

      def to_menu
        @menu = Chrome::MENU.index { |i| i.key == lit } || 0
        @focus = :menu
      end

      def menu_key(key)
        case key
        when :left, :right then @menu = (@menu + (key == :left ? -1 : 1)) % Chrome::MENU.size
        when :down then @focus = :main
        when :up then to_bar
        when :enter then go(Chrome::MENU[@menu].key)
        end
      end

      # A hotkey opens its place from anywhere.
      def hotkey(key)
        return unless key.is_a?(String) && Chrome::HOTKEYS.key?(key.downcase)

        go(Chrome::HOTKEYS[key.downcase]) || true
      end

      # Opens the place +key+: a tab, a place of the sub-menu, Help.
      def go(key)
        return quit if key == :quit

        @focus = :main
        return search if key == :search
        return account if key == :account

        target = section_view(key)
        return unless target

        @section = key
        @tab = key == :own ? :own : :discover unless key == :help
        reset(target)
      end
    end
  end
end
