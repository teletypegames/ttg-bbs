# frozen_string_literal: true

require_relative 'modern/pharos'
require_relative 'modern/helpers'
require_relative 'modern/results_window'
require_relative 'modern/article_window'
require_relative 'modern/menu'

module UI
  # The proxy on a modern terminal (ANSI colours, UTF-8, a mouse): a desktop
  # under a menubar, the search in a dialog, the results and the article in
  # two-pane windows that can fill the screen.
  module Modern
    PARTS = [ResultsWindow, ArticleWindow, Menu].freeze

    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Alexandria BBS', note: 'Articles from wikipedia.org, under CC BY-SA.')
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
        PARTS.each { |part| part.install(self) }
      end
    end
  end
end
