# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/library'
require_relative 'modern/desktop'
require_relative 'modern/rfc_card'
require_relative 'modern/shelves_window'
require_relative 'modern/rfcs_window'
require_relative 'modern/menu'
require_relative 'modern/reader_window'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the shelves and their RFCs in two-pane windows with an
  # RFC's record on the right, a search box, an RFC's links, and a reader
  # window that shows the RFC as it was published (lib/ui/modern/reader_window).
  module Modern
    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'HackerCave BBS', note: 'The RFCs are the work of the IETF and the RFC Editor.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.application(bbs)
      BBS::Application.define do
        theme BBS::Theme.synchronet
        services bbs.services
        helpers { include Library, Desktop, RfcCard }
        [ShelvesWindow, RfcsWindow, Menu].each { |part| part.define(self) }
        on_tick { statusbar.right_text = status_text }
        init { open_desktop }
      end
    end
  end
end
