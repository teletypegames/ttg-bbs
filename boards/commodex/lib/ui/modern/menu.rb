# frozen_string_literal: true

module UI
  module Modern
    # The menubar, the status bar's hints and the desktop under them.
    module Menu
      KEYS = 'F2 Search · F3 Random game · Enter — about the game · Alt+letter — the buttons and the menus · ' \
             'Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full screen and back · ' \
             'F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off'

      module_function

      def install(app)
        app.menubar { Menu.menus(self) }
        hints(app)
        app.on_tick { statusbar.right_text = status_text }
        app.init { desktop }
      end

      def menus(bar)
        bar.menu('&Games') { Menu.games(self) }
        bar.menu('&Help') do
          item('&About') { note(Words::ABOUT, ' About ') }
          item('&Sources') { note(Words::SOURCES, ' Sources ') }
          item('&Keys') { note(KEYS, ' Keys ') }
        end
      end

      def games(menu)
        menu.item('&Search…', shortcut: 'F2') { search }
        menu.item('&Random game', shortcut: 'F3') { random }
        menu.separator
        menu.item('By &year') { years }
        menu.item('By &genre') { genres }
        menu.item('By &company') { companies }
        menu.item('With &tips') { with_tips }
        menu.separator
        menu.item('&Log off', shortcut: 'Alt-X') { :halt }
      end

      def hints(app)
        app.status_hint('F2',  'Search') { search }
        app.status_hint('F3',  'Random') { random }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
