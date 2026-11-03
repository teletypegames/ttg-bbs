# frozen_string_literal: true

module UI
  module Petscii
    # Memory Alpha on the C64: the library computer's prompt, the search
    # results, an article as its contents, each section paged, and the
    # article's QR code.
    class Reader
      class Failed < StandardError; end

      # The colours of an article, in the keys of a BBS::Theme.
      MARKDOWN   = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze
      QR_COMMAND = { 'c' => 'qr code' }.freeze
      HEADING    = 'LIBRARY COMPUTER'

      def initialize(library, screen)
        @library = library
        @screen  = screen
      end

      # Asks for a title or words and shows what Memory Alpha has.
      def search
        @screen.title(HEADING)
        @screen.puts
        @screen.say('A title opens its article, any other words the search results. Return alone: back.', color: GR)
        @screen.puts
        query = @screen.ask(" #{WH}search#{LG}> ", max: 80)
        look_up(query) unless query.strip.empty?
      end

      def random = read(@library.random || raise(Failed, 'Memory Alpha did not answer. Try again later.'))

      def read(title) = show(@library.article(title) || not_found(title))

      def read_episode(episode) = show(@library.article_of(episode) || not_found(episode.title))

      private

      def not_found(title) = raise(Failed, "Memory Alpha has no article \"#{title}\", or did not answer.")

      def look_up(query)
        @screen.puts " #{GR}accessing…#{LG}"
        article, results = @library.look_up(query)
        return show(article) if article
        raise Failed, 'Memory Alpha did not answer. Try again later.' if results.nil?
        raise Failed, "Nothing found for \"#{query}\"." if results.empty?

        loop do
          hit = @screen.pick("SEARCH: #{query.upcase}"[0, 30], results, &:title)
          break unless hit

          read(hit.title)
        end
      end

      def show(article)
        heading = article.title.upcase[0, 30]
        if article.sections.size == 1
          section(article, article.sections.first, heading, wait: false)
          qr(article) if @screen.actions(['c', 'qr code'], %w[q back]) == 'c'
        else
          contents(article, heading)
        end
      end

      def contents(article, heading)
        loop do
          picked = @screen.pick(heading, article.sections, commands: QR_COMMAND, &:title)
          break unless picked

          picked == 'c' ? qr(article) : section(article, picked, heading)
        end
      end

      def section(article, section, heading, wait: true)
        lines = BBS::Markdown.to_lines(section.markdown, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }
        if section == article.sections.first
          lines.unshift(" #{GR}(redirected from #{article.redirected_from})#{LG}", '') if article.redirected_from
          lines += ['', " #{GR}memory alpha, under cc by-nc:#{LG}", *article.url.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
        else
          lines.unshift(" #{WH}#{section.title}#{LG}", '')
        end
        @screen.page(heading, lines, wait: wait, room: 2)
      end

      # The article's address as a QR code, in the middle of the screen.
      def qr(article)
        @screen.title('SCAN THE ARTICLE')
        code   = qr_code(article.short_url)
        indent = ' ' * ((COLS - 1 - BBS::FrameBuffer.plain(code.first).size) / 2)
        code.each { |line| @screen.puts("#{indent}#{line}") }
        @screen.pause
      rescue BBS::QR::TooLong
        @screen.say('This address is too long for a QR code on the C64.', color: RD)
        @screen.pause
      end

      def qr_code(link)
        BBS::QR.petscii(link)
      rescue BBS::QR::TooLong
        BBS::QR.petscii(link, quiet: 1)
      end
    end
  end
end
