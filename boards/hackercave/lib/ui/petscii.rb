# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/reader'
require_relative 'petscii/records'
require_relative 'petscii/jargon_room'
require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the shelves and their RFCs as numbered lists, an RFC's record on a page
  # with its links and errata (Records), the reader with the RFC reflowed to
  # 38 columns (Reader), and the Jargon File (JargonRoom).
  module Petscii
    LOGO_COLORS = [GN, GN, GN, GN, GN].freeze

    # HACKERCAVE in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii(Logo::WORD, colors: LOGO_COLORS)

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, *logo, rule, "  #{WH}the hacker's reading room#{LG}",
       "  #{GR}every rfc, from 1969 to today#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Board.new(bbs.library, bbs.reading, bbs.jargon, Screen.new(runner.session)).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'hackercave bbs', color: GN, width: 38,
                                                            note: 'The RFCs are the work of the IETF.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # One call: the menu, the shelves, the searches, the lists.
    class Board
      include Records

      ABOUT = [
        " #{WH}hackercave bbs#{LG}", '',
        ' The hacker\'s reading room of Teletype Games: every RFC, the documents the Internet is made of, ' \
        'from RFC 1 of 1969 to the newest, the IENs before them, and the Jargon File.', '',
        ' The index comes from the RFC Editor (rfc-editor.org) every day, the text of every RFC from its ' \
        'mirror. The RFCs are the work of the IETF and their authors.', '',
        ' Here the RFCs are reflowed to 38 columns: a figure too wide comes in panels, its columns said ' \
        'above.', '',
        " #{GR}search: 854, std 7, ien 137, or words; status:standard and year:1983 narrow it. text search " \
        "looks in every line of every rfc. reader keys: return more, b back, t contents, f rfcs named, q record.#{LG}"
      ].freeze

      def initialize(library, reading, jargon, screen)
        @library = library
        @reading = reading
        @jargon  = jargon
        @screen  = screen
        @seen    = Set.new
      end

      def run
        @screen.cls
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          @screen.puts
          @screen.puts " #{GR}#{index_line}#{LG}"
          @choice = @screen.menu(menu_items, index: menu_items.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          return if @choice == 'q'

          take(@choice)
          @screen.title('HACKERCAVE BBS', index_note)
        end
      end

      private

      def menu_items
        @menu_items ||= [
          BBS::Selector.item('classics', key: '1', value: '1', about: 'the rfcs the internet is built on'),
          BBS::Selector.item('telnet', key: '2', value: '2', about: 'the protocol of this board'),
          BBS::Selector.item('april 1st', key: '3', value: '3', about: 'the rfcs of april fools\' day'),
          BBS::Selector.item('all shelves', key: '4', value: '4', about: 'series, status, decades, iens'),
          BBS::Selector.item('search', key: '5', value: '5', about: 'a number, std 7, or words'),
          BBS::Selector.item('search the text', key: '6', value: '6', about: 'words in every line of every rfc'),
          BBS::Selector.item('the jargon file', key: 'j', value: 'j', about: 'the lexicon of hacker slang'),
          BBS::Selector.item('most read on this board', key: '7', value: '7', about: 'what the callers here read'),
          BBS::Selector.item('about', key: 'a', value: 'a', about: 'the board, the rfcs, the keys'),
          BBS::Selector.item('log off', key: 'q', value: 'q', about: 'hang up. see you!')
        ]
      end

      def take(choice)
        case choice
        when '1', '2', '3' then shelf(@library.own_shelves[choice.to_i - 1])
        when '4' then shelves
        when '5' then search
        when '6' then search_text
        when 'j' then JargonRoom.new(@jargon, @screen).run
        when '7' then most_read
        when 'a' then @screen.page('ABOUT', ABOUT)
        end
      end

      def index_line = @library.ready? ? "#{@library.count} rfcs in the index" : 'the index is being prepared'

      def index_note = @library.ready? ? "#{@library.count} rfcs" : ''

      def not_ready
        message('The index is being prepared: it is downloaded from the RFC Editor and indexed. Try again in a ' \
                'minute. The classics, telnet and april 1st shelves are open meanwhile.')
      end

      def shelves
        return not_ready unless @library.ready?

        list = @library.shelves
        loop do
          picked = @screen.pick('SHELVES', list, right: "#{list.size} shelves") do |s|
            "#{s.name.downcase} #{GR}#{s.count}#{LG}"
          end
          return unless picked

          shelf(picked)
        end
      end

      def shelf(shelf)
        return not_ready unless shelf

        entries(shelf.name.upcase[0, 26], @library.entries_on(shelf))
      end

      def search
        return not_ready unless @library.ready?

        query = ask('SEARCH', 'An rfc number (854), ien 137, a series (std 7), or words. status:standard and ' \
                              'year:1983 narrow it.')
        found(query, @library.search(query)) if query
      end

      def search_text
        return message('The text of every RFC is being mirrored and indexed. Try again later.') unless @library.text_search?

        query = ask('SEARCH THE TEXT', 'Words anywhere in the text of the RFCs.')
        found(query, @library.search_text(query)) if query
      end

      # The line typed under +title+ and +hint+; nil when it is empty.
      def ask(title, hint)
        @screen.title(title)
        @screen.say(hint, color: GR)
        @screen.puts
        query = BBS::Field.ask(@screen.session, ' search> ', max: 60)
        query.nil? || query.strip.empty? ? nil : query
      end

      def found(query, result)
        case result
        when :too_short then message('A word of two letters or more, please.')
        when :preparing then not_ready
        when [] then message('Nothing found. Fewer or other words?')
        when Array
          return message(refused(*result)) if result.first.is_a?(Symbol)

          entries("SEARCH: #{query.strip.upcase}"[0, 26], result)
        end
      end

      def refused(why, number)
        name = number.negative? ? "IEN #{-number}" : "RFC #{number}"
        why == :not_issued ? "#{name} was never issued." : "There is no #{name} yet."
      end

      def most_read
        list = @library.most_read
        return message('Nothing has been read here yet. Be the first!') if list.empty?

        entries('MOST READ HERE', list)
      end

      def message(text)
        @screen.puts
        @screen.say(text, color: YE)
        @screen.pause
      end
    end
  end
end
