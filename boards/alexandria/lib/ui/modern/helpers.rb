# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the Application: the caller's Wikipedia, the search,
    # an article, a random one, the desktop with the Pharos.
    module Helpers
      LANGUAGES = { 'en' => 'English', 'hu' => 'Magyar', 'de' => 'Deutsch' }.freeze
      HELP      = 'F2 search · F3 random article · F4 language · Alt-X log off'
      NO_ANSWER = 'Wikipedia did not answer. Try again later.'
      QR_PADDING = { sides: 2, top: 1, bottom: 0 }.freeze
      QR_SIDES   = 4
      QR_ROWS    = 7

      def articles = services[:articles]

      def lang = context[:lang]

      def language_name = LANGUAGES.fetch(lang, lang)

      def search
        BBS::Dialogs.input(self, prompt: "Article title on #{lang}.wikipedia.org:", title: ' Search ', width: 60,
                                 on_submit: ->(text) { look_up(text) unless text.strip.empty? })
      end

      # The article titled as typed opens at once; otherwise the results.
      def look_up(query)
        article, results = with_loading('Searching Wikipedia…') { articles.look_up(query, lang: lang) }
        return open_window(:article, article: article) if article
        return open_window(:results, query: query, results: results) if results&.any?
        BBS::Dialogs.message(self, results ? "Nothing found for \"#{query}\" on #{lang}.wikipedia.org." : NO_ANSWER,
                             title: ' Search ')
      end

      def read(title)
        article = with_loading('Loading the article…') { articles.article(title, lang: lang) }
        return open_window(:article, article: article) if article
        BBS::Dialogs.message(self, "Wikipedia has no article \"#{title}\", or did not answer.", title: ' Article ')
      end

      # The article's address as a QR code, in a window as big as the
      # screen allows.
      def show_qr(article)
        code = qr_code(article.short_url, width: cols - QR_SIDES, height: rows - QR_ROWS)
        BBS::Windows::Info.open(self, title: ' Scan the article ', width: BBS::FrameBuffer.plain(code.first).size + QR_SIDES,
                                      body: code, padding: QR_PADDING)
      rescue BBS::QR::TooLong
        BBS::Dialogs.message(self, 'The screen is too small for the QR code of this article.', title: ' QR code ')
      end

      def qr_code(link, **room)
        BBS::QR.ansi(link, **room)
      rescue BBS::QR::TooLong
        BBS::QR.ansi(link, **room, quiet: 1)
      end

      def random
        title = with_loading('Picking an article…') { articles.random(lang: lang) }
        title ? read(title) : BBS::Dialogs.message(self, NO_ANSWER, title: ' Random ')
      end

      def switch_language
        context[:lang] = articles.next_language(lang)
        statusbar.right_text = status_text
        BBS::Dialogs.message(self, "Searching #{lang}.wikipedia.org (#{language_name}) from now on.", title: ' Language ')
      end

      def status_text = "#{lang}.wikipedia.org │ #{Time.now.strftime('%H:%M')}"

      def markdown(text, width) = BBS::Markdown.to_lines(text, width: width - 1, theme: theme)

      # The desktop: the Pharos above the search dialog, the keys under it.
      def desktop
        context[:lang] ||= articles.languages.first
        dialog_top = ((rows - 7) / 2) + 1
        @pharos = add(Pharos.new)
        @pharos.layout(1, [dialog_top - Pharos::HEIGHT - 1, 2].max, cols, Pharos::HEIGHT)
        add_help(dialog_top + 8)
        statusbar.right_text = status_text
        search
      end

      def add_help(row)
        help = BBS::Widgets::Label.new(text: HELP, align: :center, style_key: :text_dim)
        help.layout(1, row, cols, 1)
        add(help)
      end

      def tick
        @pharos&.tick
        statusbar.right_text = status_text
      end
    end
  end
end
