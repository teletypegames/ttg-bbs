# frozen_string_literal: true

require_relative 'transfer'
require_relative 'logo'
require_relative 'modern/actions'
require_relative 'modern/shelves'
require_relative 'modern/titles'
require_relative 'modern/menu'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the shelves in a two-pane window (modern/shelves), a
  # shelf's titles with the one picked on the right (modern/titles), and its
  # download by ZMODEM, XMODEM-1K or XMODEM (modern/actions).
  module Modern
    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'WarpEngine BBS')
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
        helpers { include Actions }
        Shelves.define(self)
        Titles.define(self)
        Menu.define(self)
        on_tick { statusbar.right_text = status_text }
        init { desktop }
      end
    end
  end
end
