# frozen_string_literal: true

require_relative 'c64/screen'

module UI
  # The proxy on a Commodore 64: PETSCII on a 40×25 screen. A title typed at
  # the prompt is looked up, the results come as a numbered list, and an
  # article as its contents, each section paged a screenful at a time.
  module C64
    LOGO_FONT = {
      'W' => %w[#.# #.# #.# ### #.#], 'I' => %w[### .#. .#. .#. ###], 'K' => %w[#.# #.# ##. #.# #.#],
      'P' => %w[##. #.# ##. #.. #..], 'R' => %w[##. #.# ##. #.# #.#], 'O' => %w[### #.# #.# #.# ###],
      'X' => %w[#.# #.# .#. #.# #.#], 'Y' => %w[#.# #.# .#. .#. .#.]
    }.freeze
    LOGO_COLORS = [CY, CY, LB, LB, "\e[0;34m"].freeze

    # The colours of an article, in the keys of a BBS::Theme.
    MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

    LANGUAGES = { 'en' => 'english', 'hu' => 'magyar', 'de' => 'deutsch' }.freeze

    # WIKIPROXY in reversed blocks, five rows.
    def self.logo
      5.times.map do |row|
        bits = 'WIKIPROXY'.chars.map { |c| LOGO_FONT[c][row] }.join('.')
        line = bits.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "  #{LOGO_COLORS[row]}#{line}#{LG}"
      end
    end

    def self.flow(wikipedia)
      BBS::Flow.define do
        call do |ctx, runner|
          Proxy.new(wikipedia, Screen.new(runner.session), ctx).run
          nil
        end
        call do |_ctx, runner|
          C64.goodbye(Screen.new(runner.session))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(screen)
      screen.cls
      screen.puts
      screen.puts " #{CY}#{RV}#{' thanks for calling wikiproxy'.ljust(39)}#{RO}#{LG}"
      screen.puts
      screen.say('Articles from wikipedia.org, under CC BY-SA. More of us: teletypegames.org', GR)
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end

    # One call: the prompt, the results, the article.
    class Proxy
      def initialize(wikipedia, screen, ctx)
        @wikipedia = wikipedia
        @screen    = screen
        @ctx       = ctx
        @ctx[:lang] ||= wikipedia.languages.first
      end

      def run
        @screen.cls
        @screen.puts
        C64.logo.each { |l| @screen.puts l }
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
          @screen.say(e.message, RD)
          @screen.pause
          @screen.title('WIKIPROXY', right)
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
        @screen.title('WIKIPROXY', right)
        @screen.puts
        @screen.puts " #{YE}R#{LG} random article"
        @screen.puts " #{YE}L#{LG} language: #{WH}#{LANGUAGES.fetch(lang, lang)}#{LG}"
        @screen.puts " #{YE}Q#{LG} log off"
        case @screen.choose("\r\n #{DG}return: back#{LG} ", ['r', 'l', 'q', :enter], back: :enter)
        when 'r'
          title = @wikipedia.random(lang: lang) or raise LookupFailed, 'Wikipedia did not answer. Try again later.'
          read(title)
        when 'l'
          @ctx[:lang] = @wikipedia.next_language(lang)
          @screen.title('WIKIPROXY', right)
        when 'q' then return :quit
        else @screen.title('WIKIPROXY', right)
        end
        nil
      end

      def look_up(query)
        @screen.puts " #{GR}searching…#{LG}"
        article, results = @wikipedia.look_up(query, lang: lang)
        return show(article) if article
        raise LookupFailed, 'Wikipedia did not answer. Try again later.' if results.nil?
        raise LookupFailed, "Nothing found for \"#{query}\"." if results.empty?

        loop do
          result = @screen.pick("SEARCH: #{query.upcase}"[0, 30], results, right: lang, &:title)
          break unless result

          read(result.title)
        end
        @screen.title('WIKIPROXY', right)
      end

      def read(title)
        @screen.puts " #{GR}loading…#{LG}"
        article = @wikipedia.article(title, lang: lang)
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
        @screen.title('WIKIPROXY', right)
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
