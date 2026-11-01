# frozen_string_literal: true

module UI
  module Modern
    # The menubar, the status bar's hints and the desktop under them.
    module Menu
      ABOUT = 'Alexandria BBS — Wikipedia on a telnet line, from Teletype Games, powered by rubbs. ' \
              'Type a title: the article of that title opens at once, otherwise the search results. ' \
              'An article opens with its sections on the left. ' \
              "The text is Wikipedia's, under CC BY-SA; the address is under each article."
      KEYS  = 'F2 Search · F3 Random article · F4 Language · Alt+letter — open menu · ' \
              'Tab/Shift-Tab — move focus · Enter — open · Esc — close window · ' \
              'F5 or Alt-Enter — full screen and back · F6 / Shift-F6 — next / previous window · ' \
              'F10 Menu · Alt-X Log off'

      module_function

      def install(app)
        app.menubar { Menu.menus(self) }
        hints(app)
        app.on_tick { tick }
        app.init { desktop }
      end

      def menus(bar)
        bar.menu('&Wiki') do
          item('&Search…',        shortcut: 'F2') { search }
          item('&Random article', shortcut: 'F3') { random }
          item('&Language…',      shortcut: 'F4') { switch_language }
          separator
          item('&Log off', shortcut: 'Alt-X') { :halt }
        end
        bar.menu('&Help') do
          item('&About') { BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) }
          item('&Keys') { BBS::Dialogs.message(self, KEYS, title: ' Keys ', width: 64) }
        end
      end

      def hints(app)
        app.status_hint('F2',  'Search') { search }
        app.status_hint('F3',  'Random') { random }
        app.status_hint('F4',  'Language') { switch_language }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
