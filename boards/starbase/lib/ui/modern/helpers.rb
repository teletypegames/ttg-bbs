# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the Application: the windows it opens, Memory Alpha's
    # answers, the QR code of an article, the desktop.
    module Helpers
      TAGLINE    = 'A Star Trek library: every series, every episode, and Memory Alpha to read.'
      HELP       = 'F2 series · F3 on this day · F4 library computer · F7 random article · Alt-X log off'
      NO_ANSWER  = 'Memory Alpha did not answer. Try again later.'
      QR_PADDING = { sides: 2, top: 1, bottom: 0 }.freeze
      QR_SIDES   = 4
      QR_ROWS    = 7

      def catalog = services[:catalog]

      def library = services[:library]

      def series_list = open_window(:series)

      def open_series(series)
        open_window(:episodes, title: series.title, entries: catalog.episodes(series).map { |e| [e, series] })
      end

      def today
        entries = catalog.on_this_day(Date.today)
        return BBS::Dialogs.message(self, 'Nothing first aired on this day.', title: ' On this day ') if entries.empty?

        open_window(:episodes, title: "First aired on #{Date.today.strftime('%B %-d')}", entries: entries, years: true)
      end

      def search
        BBS::Dialogs.input(self, prompt: 'Search Memory Alpha (a title or any words):', title: ' Library computer ',
                                 width: 60, on_submit: ->(text) { look_up(text) unless text.strip.empty? })
      end

      # The article titled as typed opens at once; otherwise the results.
      def look_up(query)
        article, results = with_loading('Accessing…') { library.look_up(query) }
        return open_window(:article, article: article) if article
        return open_window(:results, query: query, results: results) if results&.any?
        BBS::Dialogs.message(self, results ? "Nothing found for \"#{query}\"." : NO_ANSWER, title: ' Library computer ')
      end

      def read(title)
        article = with_loading('Accessing…') { library.article(title) }
        return open_window(:article, article: article) if article
        BBS::Dialogs.message(self, "Memory Alpha has no article \"#{title}\", or did not answer.", title: ' Article ')
      end

      def read_episode(episode)
        article = with_loading('Accessing…') { library.article_of(episode) }
        return open_window(:article, article: article) if article
        BBS::Dialogs.message(self, "Memory Alpha has no article on \"#{episode.title}\", or did not answer.",
                             title: ' Article ')
      end

      def random
        title = with_loading('Accessing…') { library.random }
        title ? read(title) : BBS::Dialogs.message(self, NO_ANSWER, title: ' Random ')
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

      def card(rows, width)
        t = theme
        key_width = rows.map { |k, _| k.size }.max.to_i + 2
        rows.flat_map do |key, value|
          lines = BBS::FrameBuffer.wrap_ansi(value.to_s, [width - key_width - 1, 10].max)
          lines.each_with_index.map { |l, i| "#{t[:text_dim]}#{(i.zero? ? key : '').ljust(key_width)}#{t[:text]}#{l}" }
        end
      end

      def status_text = "#{catalog.size} episodes │ #{Time.now.strftime('%H:%M')}"

      def markdown(text, width) = BBS::Markdown.to_lines(text, width: width - 1, theme: theme)

      # The desktop: the logo, the tagline and the keys, the series open.
      def desktop
        top = [(rows / 2) - 6, 3].max
        Logo.half_blocks.each_with_index { |line, i| desktop_label(line, :accent, top + i) }
        desktop_label(TAGLINE, :text, top + 4)
        desktop_label(HELP, :text_dim, top + 6)
        statusbar.right_text = status_text
        series_list
      end

      def desktop_label(text, style, row)
        label = BBS::Widgets::Label.new(text: text, align: :center, style_key: style)
        label.layout(1, row, cols, 1)
        add(label)
      end
    end
  end
end
