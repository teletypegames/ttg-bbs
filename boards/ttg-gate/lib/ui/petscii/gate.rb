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

module UI
  module Petscii
    # One C64 call of the gate: the frame (Chrome) around a view of the main
    # area, the sidebar a cursor menu beside it. CRSR left and right move
    # the focus between the sidebar and the main area, up and down move in
    # the one that has it, RETURN opens; a sidebar place's yellow letter
    # opens it from anywhere (a view's own keys first: B on a board's page
    # is its banner). ← or RUN/STOP goes back, Q hangs up.
    #
    # Each change is drawn on a new Canvas and only the cells that differ
    # from what the C64 shows go out (a patch), or the whole screen when
    # that is shorter; a new screen goes out whole.
    class Gate
      # Seconds a key is waited for before the clock is looked at.
      TICK = 0.5
      # Seconds between two steps of the dialling.
      STEP = 0.12
      INPUT_LABEL = 'Find:'
      INPUT_MAX   = Layout::HINT_WIDTH - INPUT_LABEL.length - 2
      SIDE_HINT   = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Open  ', false], ['Q', true],
                     [' Quit', false]].freeze
      WARNINGS = {
        dead: ['This board has not answered', 'our calls for 30 days.', 'It may be gone. Dial anyway?']
      }.freeze
      REFUSALS = {
        rate: ['You dialled 10 boards in', '10 minutes. Try again later.'],
        busy: ['3 callers are on this board', 'already. Try again soon.'],
        not_petscii: ['This board has no PETSCII face.'],
        unknown: ['This board is gone from the list.']
      }.freeze
      # The lists of their own: the title, the chip, its colour, the words of
      # an empty one, the BrowseService method.
      FIXED = {
        new: ['NEW THIS WEEK', '7 days', Canvas::LIGHT_GREY, 'No new board this week.', :new_this_week],
        died: ['RECENTLY DIED', '30 days', Canvas::LIGHT_RED, 'None died in 30 days.', :recently_died],
        graves: ['GRAVEYARD', 'dead', Canvas::GREY, 'No graves yet.', :graveyard]
      }.freeze
      BANDS = { discover: Canvas::LIGHT_GREEN, search: Canvas::WHITE, browse: Canvas::ORANGE, new: Canvas::PURPLE,
                died: Canvas::LIGHT_RED, graves: Canvas::GREY }.freeze

      attr_reader :focus, :stack

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
        @stack = [own]
        paint(whole: true)
      end

      def view = @stack.last

      # Answers one key; :quit when the call should end.
      def press(key)
        return side(key) if @focus == :side && %i[up down enter].include?(key)

        case key
        when :left then focus_on(:side)
        when :right then focus_on(:main)
        when :escape then back
        else
          result = view.handle(key)
          return act(result) if result
          return go(:search) if key == '/'
          go(Chrome::HOTKEYS[key.downcase]) if key.is_a?(String) && Chrome::HOTKEYS.key?(key.downcase)
        end
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
        Chrome.divider(canvas)
        Chrome.sidebar(canvas, lit: lit, stats: @stats)
        view.draw(canvas)
        if @input
          canvas.text(Layout::HINT_ROW, 0, INPUT_LABEL, Canvas::LIGHT_GREEN)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1, @input, Canvas::WHITE)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1 + @input.length, ' ', Canvas::WHITE, rvs: true)
        else
          Chrome.hint(canvas, @status || (@focus == :side ? SIDE_HINT : view.hint))
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

      def lit
        return Chrome::ITEMS[@cursor].key if @focus == :side

        view.section || @section
      end

      def stats
        @browse&.stats
      rescue StandardError
        nil
      end

      def focus_on(focus)
        return if @focus == focus

        @cursor = Chrome::ITEMS.index { |i| i.key == lit } || 0 if focus == :side
        @focus = focus
        paint
      end

      def side(key)
        case key
        when :up, :down
          @cursor = (@cursor + (key == :up ? -1 : 1)).clamp(0, Chrome::ITEMS.size - 1)
          paint
        when :enter then go(Chrome::ITEMS[@cursor].key)
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
        if @stack.size > 1
          @stack.pop
          view.reload if view.respond_to?(:reload)
          return paint
        end
        return :quit if @section == :own

        go(:own)
      end

      # Opens the place +key+ of the sidebar.
      def go(key)
        return :quit if key == :quit

        @focus = :main
        return search if key == :search

        target = section_view(key)
        return paint unless target

        @section = key
        @stack = [target]
        paint(whole: true)
      end

      def section_view(key)
        case key
        when :own then own
        when :help then Views::TextView.help
        else
          return resting unless @browse

          catalog_view(key)
        end
      end

      def catalog_view(key)
        case key
        when :discover then discover
        when :browse then browse_menu
        when :software, :country, :network then facets(key)
        when *FIXED.keys then fixed(key)
        when :random then random
        when :sources then Views::SourcesView.new(@browse.sources, @stats || {})
        end
      end

      def own = @own ||= Views::OwnView.new(@boards, on_dial: method(:dial_own))

      def discover
        @discover ||= list('PETSCII BOARDS', :discover) { |state| @browse.search('', petscii: true, state: state) }
        @discover.reload
        @discover
      end

      def list(title, section, &loader)
        Views::ListView.new(title: title, color: BANDS.fetch(section, Canvas::ORANGE), section: section, loader: loader,
                            on_open: method(:open_page), details: method(:latency))
      end

      # A list of its own: New this week, Recently died, the Graveyard.
      def fixed(key)
        title, chip, color, empty, reader = FIXED.fetch(key)
        Views::ListView.new(title: title, color: BANDS.fetch(key), section: key, filter: false, chips: [[chip, color]],
                            loader: ->(_) { @browse.public_send(reader, petscii: true) }, empty: empty,
                            on_open: method(:open_page), details: method(:latency))
      end

      def latency(id)
        @latency ||= {}
        @latency.fetch(id) { @latency[id] = @browse.page(id)&.latency_ms }
      end

      def browse_menu
        entries = @browse.axes(petscii: true).map do |axis, spec|
          facets = @browse.facets(axis, petscii: true)
          about = ["BY #{spec[:label].upcase}", *facets.first(3).map { |f| "#{f.label} #{f.count}" }]
          Views::MenuView::Entry.new(name: "BY #{spec[:label]}", count: facets.size, about: about,
                                     action: -> { push(facets(axis)) })
        end
        Views::MenuView.new(entries, title: 'BROWSE', color: BANDS[:browse], section: :browse)
      end

      def facets(axis)
        axis = axis.to_sym
        label = @browse.axes(petscii: true).dig(axis, :label).to_s
        entries = @browse.facets(axis, petscii: true).map do |f|
          Views::MenuView::Entry.new(name: f.label, count: f.count, about: [f.label, "Tag #{f.tag}", "#{f.count} boards"],
                                     action: -> { push(tagged(f, axis)) })
        end
        Views::MenuView.new(entries, title: "BY #{label.upcase}", color: BANDS[:browse], section: axis)
      end

      def tagged(facet, axis)
        list(facet.label, :browse) { |state| @browse.tagged(facet.tag, petscii: true, state: state) }.tap do |l|
          l.instance_variable_set(:@section, axis)
        end
      end

      def push(target)
        @stack.push(target)
        @focus = :main
        paint(whole: true)
        nil
      end

      def random
        board = @browse.random(petscii: true)
        return notice('RANDOM BOARD', ['No PETSCII board answered', 'our last call.'], section: :random) unless board

        page_view(board.id, :random)
      end

      def page_view(id, section)
        page = @browse.page(id)
        return notice('GONE', ['This board is gone from the list.'], section: section) unless page

        Views::PageView.new(page, section: section, on_dial: method(:dial_catalog), on_banner: method(:banner))
      end

      def open_page(listing)
        target = page_view(listing.id, view.section || @section)
        push(target)
      end

      def resting = notice('GLOBAL DISCOVERY', ['The catalog is resting.', 'Try again later.'])

      def notice(title, lines, section: nil)
        Views::TextView.new(title, lines.map { |l| [l, Canvas::YELLOW] }, color: Canvas::LIGHT_RED, section: section)
      end

      # The search: the input line in place of the hint bar, then its list.
      def search
        text = input
        return paint if text.nil? || text.empty?

        @section = :search
        @stack = [list("FIND #{text}", :search) { |state| @browse.search(text, petscii: true, state: state) }]
        paint(whole: true)
      end

      # Reads a line on the hint row: letters, digits and signs, DEL takes
      # one back, RETURN takes it, RUN/STOP gives up (nil).
      def input
        unless @browse
          show(resting)
          return nil
        end

        @input = +''
        paint
        loop do
          case (key = wait)
          when :enter then return @input.strip.downcase
          when :escape then return nil
          when :backspace then @input.chop!
          when String then @input << key if key.length == 1 && key.match?(/[[:print:]]/) && @input.length < INPUT_MAX
          end
          paint
        end
      ensure
        @input = nil
      end

      # A key, the idle time of the session counted: past it the call ends.
      def wait
        idle = 0.0
        loop do
          key = @screen.key(timeout: TICK)
          return key unless key == :idle

          idle += TICK
          raise IOError, 'idle' if @screen.idle_limit && idle >= @screen.idle_limit

          tick
        end
      end

      # Shows +target+ over the current view until a key; the key.
      def show(target, hint: [['Press a key', false]])
        target.instance_variable_set(:@hint, hint)
        @stack.push(target)
        paint
        key = wait
        @stack.pop
        paint
        key
      end

      # Our own board: its row flashes, the handshake fills the hint bar, the
      # line goes to the board, and the whole screen again when it hangs up.
      def dial_own(board)
        2.times do
          own.flash = true
          paint
          sleep STEP
          own.flash = false
          paint
          sleep STEP
        end
        (0..10).step(2) do |filled|
          @status = [['Handshake ', false], ['█' * filled, true], ['▒' * (10 - filled), false]]
          paint
          sleep STEP
        end
        @status = [['Carrier detected', true]]
        paint
        sleep STEP
        @status = nil
        hand_over { UI.dial(@screen.session, board) }
        nil
      end

      # A board of the catalog, by the dial rules: a dead one asks first, a
      # refused one says why.
      def dial_catalog(listing)
        return unless @dials.warnings(listing, face: :petscii).all? { |w| confirm(listing, w) }

        caller = UI.caller_key(@screen.session)
        refusal = @dials.check(caller, listing, face: :petscii)
        return refused(listing, refusal) if refusal

        result = nil
        hand_over { result = UI.dial_catalog(@screen.session, @dials, caller, listing, face: :petscii) }
        refreshed = @browse.page(listing.id)
        view.replace(refreshed) if refreshed && view.respond_to?(:replace) && view.is_a?(Views::PageView)
        refused(listing, result) if result.is_a?(::Discovery::DialService::Refusal)
        nil
      end

      def hand_over
        @screen.raw([Canvas::LOWERCASE, Canvas::CLEAR].pack('C*'))
        yield
      ensure
        @stats = stats
        @shown = nil
      end

      def confirm(listing, warning)
        question = Views::TextView.new(Layout.plain(listing.title), WARNINGS.fetch(warning, []).map { |l| [l, Canvas::YELLOW] },
                                       color: Canvas::YELLOW, keys: [%w[Y Dial], %w[N Back]])
        loop do
          case show(question, hint: [['Y', true], [' Dial  ', false], ['N', true], [' Back', false]])
          when 'y', 'Y' then return true
          when 'n', 'N', :escape, 'q', 'Q' then return false
          end
        end
      end

      def refused(listing, refusal)
        show(notice(Layout.plain(listing.title), REFUSALS.fetch(refusal.reason, ['The call did not go.'])))
        nil
      end

      # The first screen of a PETSCII banner as it came, until a key; then
      # the whole screen again.
      def banner(page)
        @screen.raw([Canvas::UPPERCASE, Canvas::CLEAR].pack('C*') + ::Discovery::BannerPreview.petscii(page.c64_banner))
        wait
        @shown = nil
        nil
      end
    end
  end
end
