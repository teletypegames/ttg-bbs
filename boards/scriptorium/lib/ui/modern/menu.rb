# frozen_string_literal: true

module UI
  module Modern
    # The menubar and the function keys of the modern face.
    module Menu
      ABOUT = 'Scriptorium BBS — the classic literature vault of Teletype Games, powered by rubbs. ' \
              'Tens of thousands of books from Project Gutenberg (gutenberg.org), cut into chapters for your ' \
              'terminal. The texts are public domain in the USA; check the laws of your country before you ' \
              'pass them on. Thanks to Project Gutenberg and its volunteers, who made them.'
      READING = 'Pick a book and press Enter: the board fetches its text from Project Gutenberg once, cuts it into ' \
                'chapters, and keeps it for the next reader. In the reader: PgUp/PgDn and the arrows scroll, Home/End ' \
                'go to the ends of the chapter, ← and → (or P and N) turn to the previous and the next chapter. ' \
                'F5 gives the reader the whole screen.'
      KEYS = 'F2 Classics · F3 Search · F4 Bookshelves · F7 Most read · Enter — open · Alt+letter — the ' \
             'buttons and the menus · Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full ' \
             'screen and back · F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off'

      def self.define(app)
        app.menubar do
          menu '&Library' do
            item '&Classics',    shortcut: 'F2' do classics end
            item '&Search…',     shortcut: 'F3' do search end
            item '&Bookshelves', shortcut: 'F4' do shelf_list end
            item '&Most read',   shortcut: 'F7' do most_read end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About' do help(ABOUT, ' About ') end
            item '&Reading' do help(READING, ' Reading ') end
            item '&Keys' do help(KEYS, ' Keys ') end
          end
        end
        hints(app)
      end

      def self.hints(app)
        app.status_hint('F2', 'Classics') { classics }
        app.status_hint('F3', 'Search') { search }
        app.status_hint('F4', 'Shelves') { shelf_list }
        app.status_hint('F7', 'Most read') { most_read }
        app.status_hint('F10', 'Menu', hidden: true) { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
