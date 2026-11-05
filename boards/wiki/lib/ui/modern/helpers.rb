# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the browser, the refresh, the
    # QR code of a page, and the private pages following who is on the line
    # (Wiki > Profile, Rubbs::Common::Auth).
    module Helpers
      include Wording

      # The caller's profile (Rubbs::Common::Auth::Profile) on the bare line; then the
      # browser shows the pages anew, and an account without the
      # wiki-supervisor role is told the private pages stay locked.
      def own_profile
        open_profile
        reload_details
        message(not_supervisor(identity.name), title: 'Profile') if signed_in? && !supervisor?
      end

      def page_text(page)
        locked?(page) ? "# Supervisor only\n\n#{locked_text('**Wiki > Profile** to log in.')}" : wiki.page_markdown(page)
      end

      def open_browser
        return message(EMPTY_INDEX, title: 'Wiki') if wiki.pages.empty?

        show(:browser)
      end

      # Re-reads the shared index (every session sees the new one) and reopens
      # the browser so the list reflects it.
      def refresh_pages
        result = loading('Refreshing wiki index…') { wiki.refresh(caller_key) }
        return report(result, REFRESH, title: 'Wiki') unless result == :refreshed

        close_all
        open_browser
      end

      # The address of the page picked in the browser as a QR code, for a
      # phone to open it on the web (with its pictures and diagrams).
      def show_qr
        page = window(:browser)&.selected
        return message('Pick a page in the browser first.', title: 'QR code') unless page

        qr(page.public_url, title: 'Scan the page')
      end
    end
  end
end
