# frozen_string_literal: true

module UI
  module Modern
    # The menubar and the function keys of the modern face.
    module Menu
      ABOUT = 'HackerCave BBS — the hacker\'s reading room of Teletype Games, powered by rubbs. Every RFC, the ' \
              'documents the Internet is made of, from RFC 1 of 1969 to the newest, as the RFC Editor published ' \
              'them (rfc-editor.org). The index is refreshed every day; an RFC is fetched the first time someone ' \
              'reads it and kept for the next reader. The RFCs are the work of the IETF and their authors; ' \
              'copyright the IETF Trust and the authors.'
      READING = 'Pick an RFC and press Enter: it opens as it was published, 72 columns, page by page. PgUp/PgDn ' \
                'and the arrows scroll, Home/End go to the ends. The line under the text says the page of the RFC. ' \
                'Alt-O lists its headings to jump to, Alt-R the RFCs it names; Alt-E in a list shows the errata. ' \
                'Alt-L in a list shows the RFCs an RFC obsoletes or updates, and the ones that replaced it. ' \
                'F5 gives the reader the whole screen.'
      SEARCH = 'F3 searches by number (854, rfc 2119, ien 137), by series (std 7, bcp 14, fyi 1), or by words of the ' \
               'title, the authors, the keywords and the abstract (telnet window). status:standard (proposed, draft, ' \
               'bcp, info, experimental, historic) and year:1983 narrow it. F9 searches the full text of every RFC, ' \
               'mirrored from the RFC Editor and indexed every day.'
      JARGON_HELP = 'The Jargon File 4.4.7 (29 Dec 2003), the lexicon of hacker slang, public domain: its entries by ' \
                    'letter, a search, the word of the day, a random entry, and the introduction, Hacker Folklore and ' \
                    'the portrait of J. Random Hacker to read. Alt-L in an entry lists the entries it links to.'
      KEYS = 'F2 Classics · F3 Search · F4 Shelves · F7 Most read · F8 Newest · F9 Search text · Enter — read · ' \
             'Alt+letter — the ' \
             'buttons and the menus · Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full ' \
             'screen and back · F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off'

      # The items of the Help menu: [label, text, window title].
      HELP = [['&About', ABOUT, ' About '], ['&Reading', READING, ' Reading '], ['&Search', SEARCH, ' Search '],
              ['&Jargon File', JARGON_HELP, ' Jargon File '],
              ['&Keys', KEYS, ' Keys ']].freeze

      # The items of the RFC menu: [label, function key or nil, helper].
      RFC = [['&Classics', 'F2', :classics], ['&Telnet', nil, :telnet], ['&Search…', 'F3', :search],
             ['Search te&xt…', 'F9', :search_text], ['S&helves', 'F4', :shelf_list], ['This m&onth', nil, :this_month],
             ['&IENs', nil, :iens], ['&Most read', 'F7', :most_read], ['&Newest', 'F8', :newest]].freeze
      # The items of the Jargon menu.
      JARGON = [['&Word of the day', nil, :jargon_today], ['&Lexicon A-Z', nil, :jargon_letters],
                ['&Search the lexicon…', nil, :jargon_search], ['&Random entry', nil, :jargon_random],
                ['&Folklore and chapters', nil, :jargon_chapters]].freeze

      def self.define(app)
        app.menubar do
          menu '&RFC' do
            RFC.each { |label, key, helper| key ? item(label, shortcut: key) { send(helper) } : item(label) { send(helper) } }
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Jargon' do
            JARGON.each { |label, _, helper| item(label) { send(helper) } }
          end
          menu '&Help' do
            HELP.each { |label, text, title| item(label) { help(text, title) } }
          end
        end
        hints(app)
      end

      def self.hints(app)
        app.status_hint('F2', 'Classics') { classics }
        app.status_hint('F3', 'Search') { search }
        app.status_hint('F4', 'Shelves') { shelf_list }
        app.status_hint('F7', 'Most read') { most_read }
        app.status_hint('F8', 'Newest', hidden: true) { newest }
        app.status_hint('F9', 'Text', hidden: true) { search_text }
        app.status_hint('F10', 'Menu', hidden: true) { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
