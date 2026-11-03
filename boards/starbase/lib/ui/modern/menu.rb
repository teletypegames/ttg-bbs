# frozen_string_literal: true

module UI
  module Modern
    # The menubar, the status bar's hints and the desktop under them.
    module Menu
      ABOUT = 'Starbase BBS — a Star Trek library on a telnet line, from Teletype Games, powered by rubbs. ' \
              'Every series and film with its episodes, the day each first aired, its directors and writers ' \
              '(Wikidata, CC0), and the articles of Memory Alpha, the fan wiki (CC BY-NC), read section by ' \
              'section. Star Trek is a trademark of Paramount; this is a fan library, not affiliated with it.'
      KEYS  = 'F2 Series · F3 On this day · F4 Library computer (search) · F7 Random article · ' \
              'Alt+letter — open menu · Tab/Shift-Tab — move focus · Enter — open · Esc — close window · ' \
              'F5 or Alt-Enter — full screen and back · F6 / Shift-F6 — next / previous window · ' \
              'F10 Menu · Alt-X Log off'

      module_function

      def install(app)
        app.menubar { Menu.menus(self) }
        hints(app)
        app.on_tick { statusbar.right_text = status_text }
        app.init { desktop }
      end

      def menus(bar)
        bar.menu('&Starbase') do
          item('&Series',           shortcut: 'F2') { series_list }
          item('&On this day',      shortcut: 'F3') { today }
          item('&Library computer…', shortcut: 'F4') { search }
          item('&Random article', shortcut: 'F7') { random }
          separator
          item('&Log off', shortcut: 'Alt-X') { :halt }
        end
        bar.menu('&Help') do
          item('&About') { BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) }
          item('&Keys') { BBS::Dialogs.message(self, KEYS, title: ' Keys ', width: 64) }
        end
      end

      def hints(app)
        app.status_hint('F2',  'Series') { series_list }
        app.status_hint('F3',  'Today') { today }
        app.status_hint('F4',  'Search') { search }
        app.status_hint('F7',  'Random') { random }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
