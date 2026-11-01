# frozen_string_literal: true

require_relative 'discovery_board'
require_relative 'board_screen'

module UI
  module Petscii
    # Global Discovery on a C64 (TTG_DISCOVERY.md §8.3): the switchboard of
    # the catalog, eight nodes a page, a state mark on each. Only PETSCII
    # boards, and not the dead ones but in the Graveyard or a search with
    # ALL: the gate carries the bytes as they are, and an ANSI board on a C64
    # is noise. The home menu lists every board, Search (a 40-column input
    # line), Browse (by Software, Country and Network: by Terminal is all
    # PETSCII here), New this week, a Random board, Recently died and the
    # Graveyard. RETURN opens a board's page, where RETURN dials it.
    class Discovery
      INPUT_ROW = Switchboard::HELP_ROW
      INPUT_MAX = Canvas::COLS - 7

      WARNINGS = {
        dead: ['THIS BOARD HAS NOT ANSWERED', 'OUR CALLS FOR 30 DAYS.', 'IT MAY BE GONE. DIAL ANYWAY?']
      }.freeze
      REFUSALS = {
        rate: ['YOU DIALLED 10 BOARDS IN', '10 MINUTES. TRY AGAIN LATER.'],
        busy: ['3 CALLERS ARE ON THIS BOARD', 'ALREADY. TRY AGAIN SOON.'],
        not_petscii: ['THIS BOARD HAS NO PETSCII FACE.'],
        unknown: ['THIS BOARD IS GONE FROM THE LIST.']
      }.freeze

      def initialize(screen, browse, dials)
        @screen = screen
        @browse = browse
        @dials  = dials
      end

      # Runs the home menu until the caller turns back to our own boards (G,
      # Q or RUN/STOP).
      def run
        return off unless @browse

        board = DiscoveryBoard.new(home, title: 'GLOBAL DISCOVERY', help: :home)
        navigate(board, home: true) { |entry| entry.action.call }
      end

      private

      def home
        boards = @browse.search('', petscii: true)
        online = boards.count { |b| b.state == 'online' }
        [
          entry('PETSCII BOARDS', boards.size, ["#{boards.size} LISTED, #{online} ONLINE", 'THE DEAD ONES APART']) { every },
          entry('SEARCH', '', ['WORDS AND TAGS: HU ONLINE', 'ALL: THE DEAD TOO', 'OR PRESS / ANYWHERE']) { search },
          entry('BROWSE', '', ['BY SOFTWARE, COUNTRY', 'OR NETWORK']) { browse_menu },
          entry('NEW THIS WEEK', @browse.new_this_week(petscii: true).size, ['FIRST LISTED IN 7 DAYS']) { new_this_week },
          entry('RANDOM BOARD', '', ['AN ONLINE ONE']) { random },
          entry('RECENTLY DIED', @browse.recently_died(petscii: true).size, ['DEAD IN THE LAST 30 DAYS']) { died },
          entry('GRAVEYARD', @browse.graveyard(petscii: true).size, ['EVERY DEAD BOARD', 'NEVER DELETED']) { graveyard },
          entry('SOURCES', '', ['WHERE THE LIST COMES FROM']) { sources }
        ]
      end

      def entry(name, right, about, &action) = DiscoveryBoard::Entry.new(name: name, right: right, about: about, action: action)

      # The keys of a switchboard: CRSR moves, +/- and CRSR left/right turn
      # the pages, RETURN or a digit takes the node (yields it), / searches,
      # Q or RUN/STOP comes back (on the home menu G too). The rain falls
      # while the caller thinks.
      def navigate(board, home: false, &block)
        @screen.raw(board.frame)
        idle = 0.0
        loop do
          key = @screen.key(timeout: TICK)
          if key == :idle
            idle += TICK
            raise IOError, 'idle' if @screen.idle_limit && idle >= @screen.idle_limit

            @screen.raw(board.rain)
            next
          end

          idle = 0.0
          case key
          when :escape, 'q', 'Q' then return
          when 'g', 'G' then return if home
          when *MOVES.keys then @screen.raw(board.move(MOVES[key]))
          when *PAGES.keys then @screen.raw(board.turn(PAGES[key]))
          when '/'
            search
            @screen.raw(board.frame)
          when :enter
            take(board, &block)
            @screen.raw(board.frame)
          when /\A[1-#{Switchboard::PER_PAGE}]\z/
            next unless board.board_at(key.to_i)

            @screen.raw(board.select(key.to_i - 1))
            take(board, &block)
            @screen.raw(board.frame)
          end
        end
      end

      # A key, the idle time of the session counted: past it the call ends.
      def key
        idle = 0.0
        loop do
          key = @screen.key(timeout: TICK)
          return key unless key == :idle

          idle += TICK
          raise IOError, 'idle' if @screen.idle_limit && idle >= @screen.idle_limit
        end
      end

      def take(board)
        item = board.selected
        yield item if item
      end

      # A list of boards: RETURN opens a board's page; the list keeps its
      # place.
      def list(title, boards)
        board = DiscoveryBoard.new(boards, title: title)
        navigate(board) { |listing| page(listing.id) }
      end

      def every = list('PETSCII BOARDS', @browse.search('', petscii: true))

      def new_this_week = list('NEW THIS WEEK', @browse.new_this_week(petscii: true))

      def died = list('RECENTLY DIED', @browse.recently_died(petscii: true))

      def graveyard = list('GRAVEYARD', @browse.graveyard(petscii: true))

      def random
        board = @browse.random(petscii: true)
        return notice('RANDOM BOARD', ['NO PETSCII BOARD ANSWERED', 'OUR LAST CALL.']) unless board

        page(board.id)
      end

      def browse_menu
        entries = @browse.axes(petscii: true).map do |axis, spec|
          top = @browse.facets(axis, petscii: true).first(2).map { |f| "#{f.label} #{f.count}" }
          entry("BY #{spec[:label]}", '', top) { facets(axis, spec[:label]) }
        end
        navigate(DiscoveryBoard.new(entries, title: 'BROWSE', help: :menu)) { |e| e.action.call }
      end

      def facets(axis, label)
        entries = @browse.facets(axis, petscii: true).map do |f|
          entry(f.label, f.count, [f.tag]) { list(f.label, @browse.tagged(f.tag, petscii: true)) }
        end
        return notice("BY #{label}", ['NOTHING HERE YET.']) if entries.empty?

        navigate(DiscoveryBoard.new(entries, title: "BY #{label}", help: :menu)) { |e| e.action.call }
      end

      # The 40-column input line of a search, then its list.
      def search
        text = input('FIND:')
        return if text.nil? || text.empty?

        list("FIND #{text}", @browse.search(text, petscii: true))
      end

      # Reads a line on the input row: letters, digits and signs, DEL takes
      # one back, RETURN takes it, RUN/STOP gives up (nil).
      def input(label)
        text = +''
        loop do
          canvas = Canvas.new
          canvas.text(INPUT_ROW, 0, label, Canvas::LIGHT_GREEN)
          canvas.text(INPUT_ROW, label.length + 1, text.upcase, Canvas::WHITE)
          canvas.text(INPUT_ROW, label.length + 1 + text.length, ' ', Canvas::WHITE, rvs: true)
          @screen.raw(canvas.span(INPUT_ROW, 0, Canvas::COLS))
          case (key = self.key)
          when :enter then return text.strip.downcase
          when :escape then return nil
          when :backspace then text.chop!
          when String then text << key if key.length == 1 && key.match?(/[[:print:]]/) && text.length < INPUT_MAX
          end
        end
      end

      # A board's page: RETURN dials, B shows the banner, Q comes back.
      def page(id)
        loop do
          page = @browse.page(id)
          return unless page

          screen = BoardScreen.new(page)
          @screen.raw(screen.frame)
          case key
          when :enter, 'd', 'D' then dial(page.listing)
          when 'b', 'B' then banner(page) if screen.banner?
          when :escape, :left, 'q', 'Q' then return
          end
        end
      end

      def dial(listing)
        return unless @dials.warnings(listing, face: :petscii).all? { |w| confirm(listing, w) }

        caller = UI.caller_key(@screen.session)
        refusal = @dials.check(caller, listing, face: :petscii)
        return refused(listing, refusal) if refusal

        @screen.raw([Canvas::LOWERCASE, Canvas::CLEAR].pack('C*'))
        result = UI.dial_catalog(@screen.session, @dials, caller, listing, face: :petscii)
        refused(listing, result) if result.is_a?(::Discovery::DialService::Refusal)
      end

      def confirm(listing, warning)
        @screen.raw(BoardScreen.notice(listing.title, WARNINGS.fetch(warning, []), 'Y DIAL   N BACK'))
        loop do
          case key
          when 'y', 'Y' then return true
          when 'n', 'N', :escape, 'q', 'Q' then return false
          end
        end
      end

      def refused(listing, refusal) = notice(listing.title, REFUSALS.fetch(refusal.reason))

      def notice(title, lines)
        @screen.raw(BoardScreen.notice(title, lines, 'PRESS A KEY'))
        key
      end

      # The first screen of a PETSCII banner as it came, until a key.
      def banner(page)
        @screen.raw([Canvas::CLEAR].pack('C*') + ::Discovery::BannerPreview.petscii(page.banner))
        key
      end

      def sources
        lines = @browse.sources.select { |s| s['last_parse_at'] }.map { |s| s['name'] }
        @screen.raw(BoardScreen.notice('SOURCES', [*lines, '', 'COUNTRIES: DB-IP.COM (CC BY 4.0)', '',
                                                   'OPT-OUT: WIKI.TELETYPEGAMES.ORG', 'SERVICES/TTG-GATE-BBS'],
                                       'PRESS A KEY'))
        key
      end

      def off = notice('GLOBAL DISCOVERY', ['THE CATALOG IS RESTING.', 'TRY AGAIN LATER.'])
    end
  end
end
