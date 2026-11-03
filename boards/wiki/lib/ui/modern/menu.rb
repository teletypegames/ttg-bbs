# frozen_string_literal: true

module UI
  module Modern
    # The menubar, the status bar's hints, and the browser on start.
    module Menu
      KEYS = 'Up/Down: pick page - Tab: focus reader - PgUp/PgDn: scroll - ' \
             'F3: QR code of the page - F5: window/full screen - * = supervisor only'

      module_function

      def install(app)
        app.init { open_browser }
        app.menubar { Menu.menus(self) }
        hints(app)
      end

      def menus(bar)
        bar.menu('&Wiki') do
          item('&Supervisor login...') { supervisor_login }
          separator
          item('&Browse pages', shortcut: 'F2') { open_browser }
          item('Page &QR code', shortcut: 'F3') { show_qr }
          item('&Refresh index', shortcut: 'F8') { refresh_pages }
          separator
          item('E&xit', shortcut: 'Alt-X') { :halt }
        end
        bar.menu('&Help') do
          item('&Keys') { BBS::Dialogs.message(self, KEYS, title: ' Keys ', width: 76) }
          item('&About') { show_about }
        end
      end

      def hints(app)
        app.status_hint('F2',  'Browse')  { open_browser }
        app.status_hint('F3',  'QR')      { show_qr }
        app.status_hint('F8',  'Refresh') { refresh_pages }
        app.status_hint('F10', 'Menu')    { menubar.open(0) }
        app.status_hint('Alt-X', 'Quit')  { :halt }
      end
    end
  end
end
