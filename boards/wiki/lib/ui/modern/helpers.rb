# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the Application: the supervisor lock of the call, the
    # browser, the refresh and the About box.
    module Helpers
      ABOUT_WIDTH = 56

      def wiki = services[:wiki]

      def unlocked? = context[:unlocked] == true

      # Who a refresh is counted for: the caller's address, not the session.
      def caller_key = BBS::RateLimit.caller_key(session)

      def supervisor_login
        return open_window(:supervisor_login) unless unlocked?
        BBS::Dialogs.confirm(self, 'Supervisor access is active. Lock it again?',
                             on_yes: -> { context[:unlocked] = false })
      end

      # The browser opens maximized: as much of the page as the screen holds.
      def open_browser
        if wiki.pages.empty?
          return BBS::Dialogs.message(self, 'The wiki index is empty. Try Wiki > Refresh index.', title: ' Wiki ')
        end
        browser = open_window(:browser)
        browser.toggle_maximize unless browser.maximized?
      end

      # Re-reads the shared index (every session sees the new one) and reopens
      # the browser so the list reflects it.
      def refresh_pages
        case with_loading('Refreshing wiki index...') { wiki.refresh(caller_key) }
        when :refreshed
          close_window while top_window
          open_browser
        when :limited then BBS::Dialogs.message(self, 'The index was just refreshed. Try again in a minute.',
                                                title: ' Wiki ')
        else BBS::Dialogs.message(self, 'Could not reach the wiki.', title: ' Error ')
        end
      end

      def show_about
        BBS::Windows::Info.open(self, title: ' About ', width: ABOUT_WIDTH, body: about)
      end

      def about
        [{ text: 'TTG Wiki BBS', style: :accent, align: :center },
         { text: 'The Teletype Games wiki over telnet', align: :center },
         :spacer, :rule,
         { kv: [['Source', wiki.base_url], ['Pages', wiki.pages.size.to_s], ['Engine', 'rubbs / Grav']] }]
      end
    end
  end
end
