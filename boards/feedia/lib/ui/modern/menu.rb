# frozen_string_literal: true

module UI
  module Modern
    # The menubar and the statusbar's keys.
    module Menu
      ABOUT = 'Feedia BBS — an RSS reader on a telnet line, from Teletype Games, powered by rubbs. ' \
              'Pick a feed, then an item: its text opens on the right, its links numbered under it. ' \
              'A feed missing from the list? Suggest it in the Admins menu.'
      KEYS  = 'F2 Feeds · F7 Suggest a feed · F8 Feedback · Alt+letter — open menu · ' \
              'Tab/Shift-Tab — move focus · Enter — open · Esc — close window · ' \
              'F5 or Alt-Enter — full screen and back · F6 / Shift-F6 — next / previous window · ' \
              'F10 Menu · Alt-X Log off'

      module_function

      def install(app)
        app.menubar do
          menu '&Feeds' do
            item '&Feed list', shortcut: 'F2' do feed_list end
            separator
            item '&Log off', shortcut: 'Alt-X' do :halt end
          end
          menu '&Admins' do
            item '&Suggest a feed…', shortcut: 'F7' do suggest end
            item 'Send &feedback…',  shortcut: 'F8' do feedback end
          end
          menu '&Help' do
            item '&About' do BBS::Dialogs.message(self, ABOUT, title: ' About ', width: 64) end
            item '&Keys' do BBS::Dialogs.message(self, KEYS, title: ' Keys ', width: 64) end
          end
        end
        hints(app)
      end

      def hints(app)
        app.status_hint('F2',  'Feeds') { feed_list }
        app.status_hint('F7',  'Suggest') { suggest }
        app.status_hint('F8',  'Feedback') { feedback }
        app.status_hint('F10', 'Menu') { menubar.open(0) }
        app.status_hint('Alt-X', 'Bye') { :halt }
      end
    end
  end
end
