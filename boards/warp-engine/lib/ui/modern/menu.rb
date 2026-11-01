# frozen_string_literal: true

module UI
  module Modern
    # The menubar, its help texts and the statusbar keys.
    module Menu
      ABOUT = 'WarpEngine BBS — the file area of Teletype Games on a telnet line, powered by rubbs. ' \
              'The shelves are the folders the WarpEngine of teletypegames.org keeps for machines without ' \
              'a web browser: pick one, pick a title, and take it home by ZMODEM or XMODEM.'
      DOWNLOADS = 'ZMODEM (Enter or Z): SyncTERM, NetRunner, Qodem and the web terminal start it by themselves. ' \
                  'XMODEM-1K (K) and XMODEM (M): start the download in your terminal, name the file, and the board ' \
                  'sends it; a Commodore terminal (CCGMS, Novaterm, UltimateTerm) takes these. Every file is checked ' \
                  'against its shelf before it goes.'
      KEYS = 'F2 Shelves · Enter — open / ZMODEM · Alt+letter — the buttons and the menus · ' \
             'Tab/Shift-Tab — move focus · Esc — close window · F5 or Alt-Enter — full screen and back · ' \
             'F6 / Shift-F6 — next / previous window · F10 Menu · Alt-X Log off'

      def self.define(app)
        app.menubar do
          menu '&Files' do
            item '&Shelves', shortcut: 'F2' do shelf_list end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Help' do
            item '&About' do BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) end
            item '&Downloads' do BBS::Dialogs.message(self, DOWNLOADS, title: ' Downloads ', width: 64) end
            item '&Keys' do BBS::Dialogs.message(self, KEYS, title: ' Keys ', width: 64) end
          end
        end
        hints(app)
      end

      def self.hints(app)
        app.status_hint('F2', 'Shelves') { shelf_list }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
