# frozen_string_literal: true

require_relative 'logo'
require_relative 'card'
require_relative 'modern/helpers'
require_relative 'modern/series_window'
require_relative 'modern/episodes_window'
require_relative 'modern/results_window'
require_relative 'modern/article_window'
require_relative 'modern/menu'

module UI
  # The library on a modern terminal (ANSI colours, UTF-8, a mouse): a
  # desktop under a menubar, the series, a series' episodes and the
  # episodes aired on this day in two-pane windows, Memory Alpha's articles
  # with their sections on the left.
  module Modern
    PARTS = [SeriesWindow, EpisodesWindow, ResultsWindow, ArticleWindow, Menu].freeze

    def self.flow(bbs)
      app = application(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.modern(runner, title: 'Starbase BBS', note: 'Articles from memory-alpha.fandom.com, under CC BY-NC.')
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
