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
    # content, two tabs and the active one's sub-menu above it. O and D
    # switch the tabs from anywhere. On Global Discovery CRSR up from the
    # top of a list (or from a page) moves the focus to the sub-menu: there
    # CRSR left and right move its bar, RETURN opens, CRSR down goes back to
    # the content. A yellow sign of the sub-menu opens its place from
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
        return menu_key(key) || true if @focus == :menu && %i[left right up down enter].include?(key)
        return to_menu || true if key == :up && to_menu?
        return back || true if key == :escape

        view.handle(key) || hotkey(key)
      end

      # The screen as it is now: the frame around the view, the search line
      # or the hint bar, the cursor resting at the end of the hint row.
      def draw(canvas)
        Chrome.bar(canvas, active: @tab == :own ? :own : :discover)
        if @tab == :own
          Chrome.own_line(canvas, @boards.size)
        else
          Chrome.menu(canvas, lit: lit, focused: @focus == :menu)
        end
        view.draw(canvas)
        if line
          input_line(canvas)
        else
          Chrome.hint(canvas, @status || (@focus == :menu ? MENU_HINT : view.hint))
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

      def hint = @status || (@focus == :menu ? MENU_HINT : view.hint)

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
