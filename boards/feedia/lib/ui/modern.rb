# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/helpers'
require_relative 'modern/two_pane'
require_relative 'modern/feeds_window'
require_relative 'modern/channel_window'
require_relative 'modern/suggest_window'
require_relative 'modern/feedback_window'
require_relative 'modern/menu'
require_relative 'modern/masthead'

module UI
  # The reader on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the feeds in a two-pane window, a feed's items with the
  # one picked on the right, and two forms that write to the admins. Each
  # window is a module of its own under lib/ui/modern.
  module Modern
    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Feedia BBS', note: "The stories are their publishers'.")
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
        helpers { include Helpers }
        [FeedsWindow, ChannelWindow, SuggestWindow, FeedbackWindow, Menu].each { |part| part.install(self) }
        on_tick { statusbar.right_text = status_text }
        init { Masthead.draw(self) }
      end
    end
  end
end
