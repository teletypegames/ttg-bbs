# frozen_string_literal: true

require_relative 'petscii/screen'

module UI
  # The reader on a Commodore 64: PETSCII on a 40×25 screen. A one-key menu,
  # the feeds and their items as numbered lists, an item paged a screenful at
  # a time, and the messages to the admins typed line by line.
  module Petscii
    LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

    # The colours of an item, in the keys of a BBS::Theme.
    MARKDOWN = { text: LG, text_bright: WH, accent: YE, label: CY, text_dim: GR }.freeze

    # FEEDIA in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii('FEEDIA', colors: LOGO_COLORS, indent: 2)

    # The logo as a newspaper's masthead: the issue line and the date
    # between rules, the motto under it.
    def self.masthead
      date  = Time.now.strftime('%a %-d %b %Y').downcase
      issue = 'vol. i  no. 2327'
      rule  = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule, " #{GR}#{issue}#{' ' * [COLS - 2 - issue.length - date.length, 1].max}#{date}#{LG}", rule,
       "  #{WH}all the news that fits in 40 columns#{LG}"]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Reader.new(bbs.feeds, bbs.inbox, Screen.new(runner.session), BBS::RateLimit.caller_key(runner.session)).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'feedia bbs', color: YE,
                                                           note: "The stories are their publishers'.")
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # One call: the menu, the feeds, their items, the messages.
    class Reader
      def initialize(feeds, inbox, screen, caller)
        @feeds  = feeds
        @inbox  = inbox
        @screen = screen
        @caller = caller
      end

      def run
        @screen.cls
        @screen.puts
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          @screen.puts
          @choice = @screen.menu(menu_items, index: menu_items.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          case @choice
          when 'f' then feed_list
          when 's' then suggest
          when 'w' then feedback
          when 'q' then return
          end
          @screen.title('FEEDIA BBS', right)
        end
      end

      private

      def right = "#{@feeds.list.size} feeds "

      def menu_items
        @menu_items ||= [
          BBS::Selector.item('feeds', key: 'f', value: 'f', about: "#{@feeds.list.size} papers to read"),
          BBS::Selector.item('suggest a feed to the admins', key: 's', value: 's', about: 'an address for the list'),
          BBS::Selector.item('write to the admins', key: 'w', value: 'w', about: 'a bug, an idea, a word of thanks'),
          BBS::Selector.item('log off', key: 'q', value: 'q', about: 'hang up. see you!')
        ]
      end

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
        @screen.page(heading, [*head(item), '', *body(item), *address(item)], right: feed.lang)
      end

      # The title and the byline of +item+.
      def head(item)
        byline = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' ')
        lines  = @screen.wrap(item.title, WIDTH).map { |l| " #{WH}#{l}#{LG}" }
        byline.empty? ? lines : [*lines, " #{GR}#{byline}#{LG}"]
      end

      def body(item)
        text = item.markdown.empty? ? '*(no text in the feed)*' : item.markdown
        BBS::Markdown.to_lines(text, width: WIDTH, theme: MARKDOWN).map { |l| " #{l}" }
      end

      def address(item)
        return [] unless item.link

        ['', " #{GR}read it all at:#{LG}", *item.link.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
      end

      def can_send?
        return true if @inbox.open?(@caller)

        answer(:limited)
        false
      end

      def suggest
        return unless can_send?

        @screen.title('SUGGEST A FEED', right)
        @screen.say('The admins look at every address before it goes on the list. Return alone: back.', GR)
        @screen.puts
        url = @screen.ask(" #{WH}address#{LG}> ", max: InboxService::MAX_FIELD)
        return if url.empty?
        return answer(:bad_url) unless InboxService.url?(url)

        name = @screen.ask(" #{WH}its name#{LG}> ", max: InboxService::MAX_FIELD)
        from = @screen.ask(" #{WH}your name#{LG}> ", max: InboxService::MAX_FIELD)
        note = @screen.ask(" #{WH}why#{LG}> ", max: InboxService::MAX_TEXT)
        answer(@inbox.suggest(caller: @caller, url: url, name: name, from: from, note: note))
      end

      def feedback
        return unless can_send?

        @screen.title('WRITE TO THE ADMINS', right)
        @screen.say('A bug, an idea, a word of thanks. Your name, then the message in the editor: ' \
                    'stop or ← and S sends it, Q goes back.', GR)
        @screen.puts
        from = @screen.ask(" #{WH}your name#{LG}> ", max: InboxService::MAX_FIELD)
        text = @screen.editor(InboxService::MAX_TEXT, 'WRITE TO THE ADMINS')
        return if text.strip.empty?

        answer(@inbox.feedback(caller: @caller, text: text, from: from))
      end

      def answer(result)
        @screen.puts
        case result
        when :ok      then @screen.say('Sent to the admins. Thank you!', GN)
        when :limited then @screen.say('That is all the messages the admins can take for now. Thank you!', GR)
        when :bad_url then @screen.say('That is not an http:// or https:// address.', RD)
        else @screen.say('The message could not be saved. Try again later.', RD)
        end
        @screen.pause
      end
    end
  end
end
