# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: search, read, a random
    # article, another Wikipedia, the network's feedback and wall.
    module Helpers
      LANGUAGES = { 'en' => 'English', 'hu' => 'Magyar', 'de' => 'Deutsch' }.freeze
      NO_ANSWER = 'Wikipedia did not answer. Try again later.'

      def lang = context[:lang]

      def language_name = LANGUAGES.fetch(lang, lang)

      def search
        ask("Article title on #{lang}.wikipedia.org:", title: 'Search', width: 60) { |text| look_up(text) }
      end

      # The article titled as typed opens at once; otherwise the results.
      def look_up(query)
        article, results = loading('Searching Wikipedia…') { articles.look_up(query, lang: lang) }
        return show(:article, article: article) if article
        return show(:results, query: query, results: results) if results&.any?

        message(results ? "Nothing found for \"#{query}\" on #{lang}.wikipedia.org." : NO_ANSWER, title: 'Search')
      end

      def read(title)
        article = loading('Loading the article…', failed: "Wikipedia has no article \"#{title}\", or did not answer.") do
          articles.article(title, lang: lang)
        end
        show(:article, article: article)
      end

      def random
        read(loading('Picking an article…', failed: NO_ANSWER) { articles.random(lang: lang) })
      end

      def switch_language
        context[:lang] = articles.next_language(lang)
        refresh_status
        message("Searching #{lang}.wikipedia.org (#{language_name}) from now on.", title: 'Language')
      end

      # The network's feedback (ttg-common TTG::Feedback), about the article
      # open, if any.
      def feedback
        article = window(:article)&.title
        with_line { TTG::Feedback.open(@session, context: article && "#{article} (#{lang}.wikipedia.org)") }
      end

      # The board's wall (TTG::Wall).
      def wall = with_line { TTG::Wall.open(@session) }
    end
  end
end
