# frozen_string_literal: true

require_relative 'petscii/screen'

module UI
  # The proxy on a Commodore 64: PETSCII on a 40×25 screen. A title typed at
  # the prompt is looked up, the results come as a numbered list, and an
  # article as its contents, each section paged a screenful at a time.
  module Petscii
    LOGO_COLORS = [CY, CY, LB, LB, BL].freeze

    # The colours of an article, in the keys of a BBS::Theme.
    MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

    LANGUAGES = { 'en' => 'english', 'hu' => 'magyar', 'de' => 'deutsch' }.freeze

    PHAROS = ['▄▀▄', '▐*▌', '▄███▄', '▐█▀█▌', '▄█████▄', '▄██▀▀▀██▄'].freeze
    WAVES  = '▄▀▀▄▄▄▀▄▄▀▀▀▄▄▀▄'

    # The Pharos of Alexandria by the sea, its light thrown both ways.
    def self.pharos
      PHAROS.each_with_index.map do |t, i|
        next "#{YE}#{'░░░▒▒▒▒▓▓▓▓████'.rjust(19)}#{LG}▐#{WH}*#{LG}▌#{YE}████▓▓▓▓▒▒▒▒░░░#{LG}" if i == 1

        "  #{LG}#{t.center(37).rstrip}"
      end + ["#{BL}#{(WAVES * 3)[0, 39]}#{LG}"]
    end

    # ALEXANDRIA in reversed blocks, five rows.
    def self.logo
      BBS::BlockFont.petscii('ALEXANDRIA', colors: LOGO_COLORS, glyphs: BBS::BlockFont::NARROW_I, indent: 2)
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          Proxy.new(bbs.articles, Screen.new(runner.session), ctx).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'alexandria bbs',
                                                           note: 'Articles from wikipedia.org, under CC BY-SA.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # One call: the prompt, the results, the article.
    class Proxy
      def initialize(articles, screen, ctx)
        @articles = articles
        @screen   = screen
        @ctx      = ctx
        @ctx[:lang] ||= articles.languages.first
      end

      def run
        @screen.cls
        @screen.puts
        Petscii.pharos.each { |l| @screen.puts l }
        @screen.puts
        Petscii.logo.each { |l| @screen.puts l }
        @screen.puts
        @screen.puts "  #{WH}wikipedia on your commodore#{LG}"
        loop do
          query = prompt
          if query
            look_up(query)
          elsif menu_choice == :quit
            return
          end
        rescue LookupFailed => e
          @screen.puts
          @screen.say(e.message, color: RD)
          @screen.pause
          @screen.title('ALEXANDRIA BBS', right)
        end
      end

      private

      class LookupFailed < StandardError
      end

      def lang = @ctx[:lang]

      def right = "#{lang}.wikipedia "

      # A title to look up, nil for the menu.
      def prompt
        @screen.puts
        @screen.puts " #{GR}type a title and return.#{LG}"
        @screen.puts " #{GR}return alone: menu#{LG}"
        query = @screen.ask(" #{WH}#{LANGUAGES.fetch(lang, lang)}#{LG}> ", max: 80)
        query.empty? ? nil : query
      end

      # :quit when the caller logs off.
      def menu_choice
        @screen.title('ALEXANDRIA BBS', right)
        @screen.puts
        items = [BBS::Selector.item('search a title', key: 's', value: :search, about: 'back to the prompt'),
                 BBS::Selector.item('random article', key: 'r', value: :random, about: 'wherever the wiki takes you'),
                 BBS::Selector.item("language: #{WH}#{LANGUAGES.fetch(lang, lang)}#{LG}", key: 'l', value: :language,
                                                                                         about: 'the next wikipedia'),
                 BBS::Selector.item('log off', key: 'q', value: :quit, about: 'hang up. see you!')]
        case @screen.menu(items, back: :search, hint: 'crsr: choose  return: take')
        when :random
          title = @articles.random(lang: lang) or raise LookupFailed, 'Wikipedia did not answer. Try again later.'
          read(title)
        when :language
          @ctx[:lang] = @articles.next_language(lang)
          @screen.title('ALEXANDRIA BBS', right)
        when :quit then return :quit
        else @screen.title('ALEXANDRIA BBS', right)
        end
        nil
      end

      def look_up(query)
        @screen.puts " #{GR}searching…#{LG}"
        article, results = @articles.look_up(query, lang: lang)
        return show(article) if article
        raise LookupFailed, 'Wikipedia did not answer. Try again later.' if results.nil?
        raise LookupFailed, "Nothing found for \"#{query}\"." if results.empty?

        loop do
          result = @screen.pick("SEARCH: #{query.upcase}"[0, 30], results, right: lang, &:title)
          break unless result

          read(result.title)
        end
        @screen.title('ALEXANDRIA BBS', right)
      end

      def read(title)
        @screen.puts " #{GR}loading…#{LG}"
        article = @articles.article(title, lang: lang)
        raise LookupFailed, "Wikipedia has no article \"#{title}\", or did not answer." if article.nil?

        show(article)
      end

      # The article: its contents when it has sections, else its pages.
      def show(article)
        heading = article.title.upcase[0, 30]
        if article.sections.size == 1
          section(article, article.sections.first, heading)
        else
          loop do
            picked = @screen.pick(heading, article.sections, right: lang, &:title)
            break unless picked

            section(article, picked, heading)
          end
        end
        @screen.title('ALEXANDRIA BBS', right)
      end

      def section(article, section, heading)
        lines = BBS::Markdown.to_lines(section.markdown, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }
        if section == article.sections.first
          lines.unshift(" #{GR}(redirected from #{article.redirected_from})#{LG}", '') if article.redirected_from
          lines += ['', " #{GR}source, under cc by-sa:#{LG}", *article.url.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
        else
          lines.unshift(" #{WH}#{section.title}#{LG}", '')
        end
        @screen.page(heading, lines, right: lang)
      end
    end
  end
end
