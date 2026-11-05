# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: a series' episodes, this
    # day's, the library computer, an article, an episode's article.
    module Helpers
      NO_ANSWER = 'Memory Alpha did not answer. Try again later.'

      def open_series(series)
        show(:episodes, caption: series.title, entries: catalog.episodes(series).map { |e| [e, series] }, years: false)
      end

      def today
        entries = catalog.on_this_day(Date.today)
        return message('Nothing first aired on this day.', title: 'On this day') if entries.empty?

        show(:episodes, caption: "First aired on #{Date.today.strftime('%B %-d')}", entries: entries, years: true)
      end

      def search
        ask('Search Memory Alpha (a title or any words):', title: 'Library computer', width: 60) { |text| look_up(text) }
      end

      # The article titled as typed opens at once; otherwise the results.
      def look_up(query)
        article, results = loading('Accessing…') { library.look_up(query) }
        return show(:article, article: article) if article
        return show(:results, query: query, results: results) if results&.any?

        message(results ? "Nothing found for \"#{query}\"." : NO_ANSWER, title: 'Library computer')
      end

      def read(title)
        show(:article, article: loading('Accessing…', failed: "Memory Alpha has no article \"#{title}\", or did not answer.") do
          library.article(title)
        end)
      end

      def read_episode(episode)
        show(:article, article: loading('Accessing…', failed: "Memory Alpha has no article on \"#{episode.title}\", " \
                                                              'or did not answer.') { library.article_of(episode) })
      end

      def random = read(loading('Accessing…', failed: NO_ANSWER) { library.random })

      # +rows+ ([label, value] pairs of UI::Card) as lines, the labels dim in
      # a column of their own.
      def card(rows, width)
        key_width = rows.map { |k, _| k.size }.max.to_i + 2
        rows.flat_map do |key, value|
          lines = Rubbs::Modern::FrameBuffer.wrap_ansi(value.to_s, [width - key_width - 1, 10].max)
          lines.each_with_index.map { |l, i| "#{dim((i.zero? ? key : '').ljust(key_width))}#{l}" }
        end
      end
    end
  end
end
