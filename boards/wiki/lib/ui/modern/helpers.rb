# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the supervisor lock of the
    # call, the browser, the refresh, the QR code of a page.
    module Helpers
      include Wording

      def unlocked? = context[:unlocked] == true

      def locked?(page) = page.private? && !unlocked?

      def supervisor_login
        return show(:supervisor_login) unless unlocked?

        confirm('Supervisor access is active. Lock it again?') do
          context[:unlocked] = false
          reload_details
        end
      end

      def unlock
        context[:unlocked] = true
        reload_details
        message(GRANTED, title: 'Unlocked')
      end

      # The browser opens maximized: as much of the page as the screen holds.
      def open_browser
        return message(EMPTY_INDEX, title: 'Wiki') if wiki.pages.empty?

        browser = show(:browser)
        browser.toggle_maximize unless browser.maximized?
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
        page = window(:browser)&.list_widget&.selected_item
        return message('Pick a page in the browser first.', title: 'QR code') unless page

        qr(page.public_url, title: 'Scan the page')
      end
    end
  end
end
