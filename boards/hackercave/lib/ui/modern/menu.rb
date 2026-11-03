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
                'Alt-L in a list shows the RFCs an RFC obsoletes or updates, and the ones that replaced it. ' \
                'F5 gives the reader the whole screen.'
      SEARCH = 'Search by number (854, rfc 2119), by series (std 7, bcp 14, fyi 1), or by words of the title, the ' \
               'authors, the keywords and the abstract (telnet window). status:standard (proposed, draft, bcp, ' \
               'info, experimental, historic) and year:1983 narrow it.'
      KEYS = 'F2 Classics · F3 Search · F4 Shelves · F7 Most read · F8 Newest · Enter — read · Alt+letter — the ' \
             'buttons and the menus · Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full ' \
             'screen and back · F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off'

      # The items of the Help menu: [label, text, window title].
      HELP = [['&About', ABOUT, ' About '], ['&Reading', READING, ' Reading '], ['&Search', SEARCH, ' Search '],
              ['&Keys', KEYS, ' Keys ']].freeze

      def self.define(app)
        app.menubar do
          menu '&RFC' do
            item '&Classics', shortcut: 'F2' do classics end
            item '&Telnet' do telnet end
            item '&Search…',   shortcut: 'F3' do search end
            item 'S&helves',   shortcut: 'F4' do shelf_list end
            item '&Most read', shortcut: 'F7' do most_read end
            item '&Newest',    shortcut: 'F8' do newest end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
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
        app.status_hint('F10', 'Menu', hidden: true) { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
