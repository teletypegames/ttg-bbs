# frozen_string_literal: true

require_relative 'chrome'
require_relative 'diff'
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
    # Each change is drawn on a new Canvas and only the cells that differ
    # from what the C64 shows go out (a patch), or the whole screen when
    # that is shorter; a new screen goes out whole.
    class Gate
      include Places
      include Dialing
      include Input

      # Seconds a key is waited for before the clock is looked at.
      TICK = 0.5
      # Seconds between two steps of the dialling.
      STEP = 0.12
      INPUT_LABEL = 'Find:'
      INPUT_MAX   = Layout::HINT_WIDTH - INPUT_LABEL.length - 2
      MENU_HINT   = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Open  ', false], ['CRSR down', true],
                     [' List', false]].freeze
      WARNINGS = {
        dead: ['This board has not answered', 'our calls for 30 days.', 'It may be gone. Dial anyway?']
      }.freeze
      REFUSALS = {
        rate: ['You dialled 10 boards in', '10 minutes. Try again later.'],
        busy: ['3 callers are on this board', 'already. Try again soon.'],
        not_petscii: ['This board has no PETSCII face.'],
        not_public: ['This board is not on the', 'public internet.'],
        unknown: ['This board is gone from the list.']
      }.freeze
      # The lists of their own: the title, the chip, its colour, the words of
      # an empty one, the BrowseService method.
      FIXED = {
        new: ['NEW THIS WEEK', '7 days', Canvas::LIGHT_GREY, 'No new board this week.', :new_this_week],
        died: ['RECENTLY DIED', '30 days', Canvas::LIGHT_RED, 'None died in 30 days.', :recently_died],
        graves: ['GRAVEYARD', 'dead', Canvas::GREY, 'No graves yet.', :graveyard]
      }.freeze
      BANDS = { discover: Canvas::LIGHT_GREEN, all: Canvas::LIGHT_GREEN, search: Canvas::WHITE, browse: Canvas::ORANGE, new: Canvas::PURPLE,
                died: Canvas::LIGHT_RED, graves: Canvas::GREY }.freeze

      attr_reader :focus, :stack, :tab

      # [screen] the C64 line (Screen)
      # [boards] our boards with a C64 face (BoardModel)
      # [browse] Discovery::BrowseService, nil without a catalog
      # [dials]  Discovery::DialService
      # [node]   the node number in the header
      # [clock]  the time, for the header
      def initialize(screen, boards:, browse:, dials:, node: 1, clock: -> { Time.now })
        @screen = screen
        @boards = boards
        @browse = browse
        @dials  = dials
        @node   = node
        @clock  = clock
        @focus  = :main
        @tab    = :own
        @cursor = 0
        @stack  = []
        @shown  = nil
        @status = nil
        @input  = nil
      end

      # Runs the call until the caller hangs up (Q, or RUN/STOP on our own
      # boards) or idles too long.
      def run
        start
        idle = 0.0
        loop do
          key = @screen.key(timeout: TICK)
          if key == :idle
            idle += TICK
            return if @screen.idle_limit && idle >= @screen.idle_limit

            tick
            next
          end

          idle = 0.0
          return if press(key) == :quit
        end
      end

      # The first screen: our own boards.
      def start
        @stats = stats
        @section = :own
        @tab = :own
        @stack = [own]
        paint(whole: true)
      end

      def view = @stack.last

      # Answers one key; :quit when the call should end.
      def press(key)
        return menu_key(key) if @focus == :menu && %i[left right up down enter].include?(key)
        return to_menu if key == :up && to_menu?
        return back if key == :escape

        result = view.handle(key)
        return act(result) if result

        go(Chrome::HOTKEYS[key.downcase]) if key.is_a?(String) && Chrome::HOTKEYS.key?(key.downcase)
      end

      # The clock: a new minute repaints its cells.
      def tick
        minute = @clock.call.strftime('%H:%M')
        return if minute == @minute

        paint
      end

      # The screen as it is now, on a Canvas.
      def compose
        canvas = Canvas.new
        Chrome.header(canvas, node: @node, time: @clock.call)
        Chrome.tabs(canvas, active: @tab, stats: @stats)
        if @tab == :own
          Chrome.own_line(canvas, @boards.size)
        else
          Chrome.menu(canvas, lit: lit, focused: @focus == :menu)
        end
        view.draw(canvas)
        if @input
          canvas.text(Layout::HINT_ROW, 0, INPUT_LABEL, Canvas::LIGHT_GREEN)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1, @input, Canvas::WHITE)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1 + @input.length, ' ', Canvas::WHITE, rvs: true)
        else
          Chrome.hint(canvas, @status || (@focus == :menu ? MENU_HINT : view.hint))
        end
        canvas
      end

      # Sends what changed since the last screen (+whole+: the whole screen).
      # The bytes sent.
      def paint(whole: false)
        canvas = compose
        bytes = whole || @shown.nil? ? canvas.frame : changes(canvas)
        @shown  = canvas
        @minute = @clock.call.strftime('%H:%M')
        return bytes if bytes.empty?

        bytes += canvas.cursor(Layout::HINT_ROW, Layout::HINT_WIDTH)
        @screen.raw(bytes)
        bytes
      end

      private

      def changes(canvas)
        changed = canvas.changes(@shown)
        return ''.b if changed.empty?

        patch = Diff.patch(canvas, changed)
        frame = canvas.frame
        patch.bytesize <= frame.bytesize ? patch : frame
      end

      # The place of the sub-menu lit: the cursor's while the menu has the
      # focus, else the section's (Browse for its axes).
      def lit
        return Chrome::MENU[@cursor].key if @focus == :menu

        section = view.section || @section
        Chrome::UNDER.fetch(section, section)
      end

      def stats
        @browse&.stats
      rescue StandardError
        nil
      end

      # CRSR up goes to the sub-menu on Global Discovery from the top of a
      # list, or from a screen without one.
      def to_menu?
        return false unless @tab == :discover && @focus == :main

        !view.is_a?(Views::Picker) || view.at_top?
      end

      def to_menu
        @cursor = Chrome::MENU.index { |i| i.key == lit } || 0
        @focus = :menu
        paint
      end

      def menu_key(key)
        case key
        when :left, :right
          @cursor = (@cursor + (key == :left ? -1 : 1)) % Chrome::MENU.size
          paint
        when :down
          @focus = :main
          paint
        when :enter then go(Chrome::MENU[@cursor].key)
        end
      end

      def act(result)
        return paint if result == :redraw

        outcome = result.call
        paint
        outcome
      end

      # Back a screen; from a section's first one to our own boards, and from
      # there the call ends.
      def back
        @focus = :main
        if @stack.size > 1
          @stack.pop
          view.reload if view.respond_to?(:reload)
          return paint
        end
        return :quit if @section == :own

        go(:own)
      end

      # Opens the place +key+: a tab, a place of the sub-menu, Help.
      def go(key)
        return :quit if key == :quit

        @focus = :main
        return search if key == :search

        target = section_view(key)
        return paint unless target

        @section = key
        @tab = key == :own ? :own : :discover unless key == :help
        @stack = [target]
        paint(whole: true)
      end
    end
  end
end
