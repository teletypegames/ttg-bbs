# frozen_string_literal: true

require_relative 'c64/screen'

module UI
  # The reader on a Commodore 64: PETSCII on a 40×25 screen. A one-key menu,
  # the feeds and their items as numbered lists, an item paged a screenful at
  # a time, and the messages to the admins typed line by line.
  module C64
    LOGO_FONT = {
      'F' => %w[### #.. ##. #.. #..], 'E' => %w[### #.. ##. #.. ###], 'D' => %w[##. #.# #.# #.# ##.],
      'I' => %w[### .#. .#. .#. ###], 'A' => %w[.#. #.# ### #.# #.#]
    }.freeze
    LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

    # The colours of an item, in the keys of a BBS::Theme.
    MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

    FEEDBACK_LINES = 10

    # FEEDIA in reversed blocks, five rows.
    def self.logo
      5.times.map do |row|
        bits = 'FEEDIA'.chars.map { |c| LOGO_FONT[c][row] }.join('.')
        line = bits.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "  #{LOGO_COLORS[row]}#{line}#{LG}"
      end
    end

    def self.flow(feeds, inbox)
      BBS::Flow.define do
        call do |ctx, runner|
          Reader.new(feeds, inbox, Screen.new(runner.session), ctx).run
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
      screen.puts " #{YE}#{RV}#{' thanks for calling feedia'.ljust(39)}#{RO}#{LG}"
      screen.puts
      screen.say("The stories are their publishers'. More of us: teletypegames.org", GR)
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end

    # One call: the menu, the feeds, their items, the messages.
    class Reader
      def initialize(feeds, inbox, screen, ctx)
        @feeds  = feeds
        @inbox  = inbox
        @screen = screen
        @ctx    = ctx
      end

      def run
        @screen.cls
        @screen.puts
        C64.logo.each { |l| @screen.puts l }
        @screen.puts
        @screen.puts "  #{WH}rss on your commodore#{LG}"
        loop do
          @screen.puts
          @screen.puts " #{YE}F#{LG} feeds"
          @screen.puts " #{YE}S#{LG} suggest a feed to the admins"
          @screen.puts " #{YE}W#{LG} write to the admins"
          @screen.puts " #{YE}Q#{LG} log off"
          case @screen.choose("\r\n #{WH}feedia#{LG}> ", %w[f s w q], back: 'q')
          when 'f' then feed_list
          when 's' then suggest
          when 'w' then feedback
          when 'q' then return
          end
          @screen.title('FEEDIA', right)
        end
      end

      private

      def right = "#{@feeds.list.size} feeds "

      def feed_list
        loop do
          feed = @screen.pick('FEEDS', @feeds.list, empty: 'no feeds are configured.', right: right) do |f|
            f.lang.empty? ? f.name : "#{f.name} #{GR}#{f.lang}#{LG}"
          end
          break unless feed

          read(feed)
        end
      end

      def read(feed)
        @screen.puts " #{GR}fetching #{feed.name.downcase}…#{LG}"
        channel = @feeds.read(feed)
        if channel.nil?
          @screen.puts
          @screen.say("#{feed.name} did not answer, or what it sent is not a feed. Try again later.", RD)
          @screen.pause
          return
        end

        heading = feed.name.upcase[0, 30]
        loop do
          item = @screen.pick(heading, channel.items, empty: 'this feed has nothing in it right now.',
                                                      right: feed.lang, &:title)
          break unless item

          show(heading, item, feed)
        end
      end

      def show(heading, item, feed)
        byline = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' ')
        body   = item.markdown.empty? ? '*(no text in the feed)*' : item.markdown
        lines  = [*@screen.wrap(item.title, WIDTH).map { |l| " #{WH}#{l}#{LG}" }]
        lines << " #{GR}#{byline}#{LG}" unless byline.empty?
        lines << ''
        lines.concat(BBS::Markdown.to_lines(body, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" })
        lines += ['', " #{GR}read it all at:#{LG}", *item.link.to_s.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }] if item.link
        @screen.page(heading, lines, right: feed.lang)
      end

      def can_send?
        return true if @ctx[:sent].to_i < Inbox::PER_CALL

        @screen.puts
        @screen.say('That is all the messages one call can send. Thank you!', GR)
        @screen.pause
        false
      end

      def suggest
        return unless can_send?

        @screen.title('SUGGEST A FEED', right)
        @screen.say('The admins look at every address before it goes on the list. Return alone: back.', GR)
        @screen.puts
        url = @screen.ask(" #{WH}address#{LG}> ", max: Inbox::MAX_FIELD)
        return if url.empty?
        return answer(:bad_url) unless Inbox.url?(url)

        name = @screen.ask(" #{WH}its name#{LG}> ", max: Inbox::MAX_FIELD)
        from = @screen.ask(" #{WH}your name#{LG}> ", max: Inbox::MAX_FIELD)
        note = @screen.ask(" #{WH}why#{LG}> ", max: Inbox::MAX_TEXT)
        answer(@inbox.suggest(url: url, name: name, from: from, note: note))
      end

      def feedback
        return unless can_send?

        @screen.title('WRITE TO THE ADMINS', right)
        @screen.say("A bug, an idea, a word of thanks. Up to #{FEEDBACK_LINES} lines; return on an empty line sends it, " \
                    'on the first one goes back.', GR)
        @screen.puts
        from  = @screen.ask(" #{WH}your name#{LG}> ", max: Inbox::MAX_FIELD)
        lines = []
        while lines.size < FEEDBACK_LINES
          line = @screen.ask("#{YE}#{(lines.size + 1).to_s.rjust(2)}#{LG}> ")
          break if line.empty?

          lines << line
        end
        return if lines.empty?

        answer(@inbox.feedback(text: lines.join("\n"), from: from))
      end

      def answer(result)
        @screen.puts
        case result
        when :ok
          @ctx[:sent] = @ctx[:sent].to_i + 1
          @screen.say('Sent to the admins. Thank you!', GN)
        when :bad_url then @screen.say('That is not an http:// or https:// address.', RD)
        else @screen.say('The message could not be saved. Try again later.', RD)
        end
        @screen.pause
      end
    end
  end
end
