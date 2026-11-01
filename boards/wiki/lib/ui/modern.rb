# frozen_string_literal: true

require_relative 'modern/helpers'
require_relative 'modern/menu'
require_relative 'modern/browser_window'
require_relative 'modern/supervisor_window'

module UI
  # The wiki on an ANSI terminal: a Norton Commander-style two-pane browser
  # that fills the screen between the menubar and the statusbar — page tree
  # on the left (indented by route depth), the selected page rendered as
  # ANSI markdown on the right. F5 / Alt-Enter (the window's zoom) puts it
  # back into a window and out again.
  module Modern
    PARTS = [Menu, BrowserWindow, SupervisorWindow].freeze

    def self.flow(bbs)
      wiki    = bbs.wiki
      browser = application(bbs)
      BBS::Flow.define do
        big_banner 'TTG WIKI', style: :success
        text(style: :muted) { "Teletype Games wiki over telnet — #{wiki.pages.size} pages indexed." }

        app browser

        say 'NO CARRIER', style: :muted
      end
    end

    def self.application(bbs)
      BBS::Application.define do
        theme BBS::Theme.nortoncommander
        services bbs.services
        helpers { include Helpers }
        PARTS.each { |part| part.install(self) }
      end
    end
  end
end
