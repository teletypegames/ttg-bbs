# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the shelves and their RFCs as numbered lists, an RFC's record on a page
  # with its links and errata (Records), the reader with the RFC reflowed to
  # 38 columns (Reader), and the Jargon File (JargonRoom).
  class Petscii < BBS::Petscii::Face
    LOGO_COLORS = [GN, GN, GN, GN, GN].freeze

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
    NOT_READY = 'The index is being prepared: it is downloaded from the RFC Editor and indexed. Try again in a ' \
                'minute. The classics, telnet and april 1st shelves are open meanwhile.'

    title('HACKERCAVE BBS') { library.ready? ? "#{library.count} rfcs" : '' }

    masthead do
      rule
      logo Logo::WORD, colors: LOGO_COLORS, indent: 0
      rule
      line "the hacker's reading room", color: WH
      line 'every rfc, from 1969 to today', color: GR
      rule
    end

    main_menu do
      item('1', 'classics', 'the rfcs the internet is built on') { shelf(library.own_shelves[0]) }
      item('2', 'telnet', 'the protocol of this board') { shelf(library.own_shelves[1]) }
      item('3', 'april 1st', 'the rfcs of april fools\' day') { shelf(library.own_shelves[2]) }
      item('4', 'all shelves', 'series, status, decades, iens') { shelves }
      item('5', 'search', 'a number, std 7, or words') { search }
      item('6', 'search the text', 'words in every line of every rfc') { search_text }
      item('j', 'the jargon file', 'the lexicon of hacker slang') { jargon_room }
      item('7', 'most read on this board', 'what the callers here read') { most_read }
      item('a', 'about', 'the board, the rfcs, the keys') { page('ABOUT', ABOUT) }
      log_off 'hang up. see you!'
    end

    # The masthead, then the main menu with the size of the index above it.
    def run
      show_masthead
      @under_masthead = true
      main_menu_loop
    end

    # The home title bar (or the masthead still up) and the size of the
    # index.
    def home
      @under_masthead ? @under_masthead = false : super
      puts " #{GR}#{library.ready? ? "#{library.count} rfcs in the index" : 'the index is being prepared'}#{LG}"
    end

    private

    def shelves
      return message(NOT_READY) unless library.ready?

      list = library.shelves
      each_pick('SHELVES', list, right: "#{list.size} shelves",
                                 label: ->(s) { "#{s.name.downcase} #{GR}#{s.count}#{LG}" }) { |s| shelf(s) }
    end

    def shelf(shelf)
      return message(NOT_READY) unless shelf

      entries(shelf.name.upcase[0, 26], library.entries_on(shelf))
    end

    def search
      return message(NOT_READY) unless library.ready?

      title('SEARCH')
      query = prompt('search', hint: 'An rfc number (854), ien 137, a series (std 7), or words. status:standard and ' \
                                     'year:1983 narrow it.', max: 60)
      found(query, library.search(query)) if query
    end

    def search_text
      return message('The text of every RFC is being mirrored and indexed. Try again later.') unless library.text_search?

      title('SEARCH THE TEXT')
      query = prompt('search', hint: 'Words anywhere in the text of the RFCs.', max: 60)
      found(query, library.search_text(query)) if query
    end

    def found(query, result)
      case result
      when :too_short then message('A word of two letters or more, please.')
      when :preparing then message(NOT_READY)
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
      list = library.most_read
      return message('Nothing has been read here yet. Be the first!') if list.empty?

      entries('MOST READ HERE', list)
    end

    def message(text)
      puts
      say(text, color: YE)
      pause
    end
  end
end

require_relative 'petscii/records'
require_relative 'petscii/reader'
require_relative 'petscii/jargon_room'
