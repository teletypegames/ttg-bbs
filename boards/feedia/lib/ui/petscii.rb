# frozen_string_literal: true

module UI
  # The reader on a Commodore 64: PETSCII on a 40×25 screen. A one-key menu,
  # the feeds and their items as numbered lists, an item paged a screenful at
  # a time, and the messages to the admins typed line by line.
  class Petscii < BBS::Petscii::Face
    LOGO_COLORS = [YE, YE, OR, OR, "\e[0;31m"].freeze
    ISSUE       = 'vol. i  no. 2327'
    NO_TEXT     = '*(no text in the feed)*'
    ANSWERS     = { ok: 'Sent to the admins. Thank you!',
                    limited: 'That is all the messages the admins can take for now. Thank you!',
                    bad_url: 'That is not an http:// or https:// address.',
                    failed: 'The message could not be saved. Try again later.' }.freeze

    title('FEEDIA BBS') { feeds_note }

    # The logo as a newspaper's masthead: the issue line and the date
    # between rules, the motto under it.
    masthead do
      gap
      rule
      gap
      logo 'FEEDIA', colors: LOGO_COLORS
      gap
      rule
      line(color: GR) do
        date = Time.now.strftime('%a %-d %b %Y').downcase
        "#{ISSUE}#{' ' * [COLS - 2 - ISSUE.length - date.length, 1].max}#{date}"
      end
      rule
      line 'all the news that fits in 40 columns', color: WH
    end

    main_menu do
      item('f', 'feeds', 'the papers to read') { feed_list }
      item('s', 'suggest a feed to the admins', 'an address for the list') { suggest }
      item('w', 'write to the admins', 'a bug, an idea, a word of thanks') { feedback }
      log_off 'hang up. see you!'
    end

    def run
      show_masthead
      @under_masthead = true
      main_menu_loop
    end

    # The home title bar, but none right under the masthead.
    def home
      @under_masthead ? @under_masthead = false : super
    end

    private

    def feeds_note = "#{feeds.list.size} feeds"

    def feed_list
      each_pick('FEEDS', feeds.list, empty: 'no feeds are configured.', right: feeds_note,
                                     label: ->(f) { f.lang.empty? ? f.name : "#{f.name} #{GR}#{f.lang}#{LG}" }) do |feed|
        read(feed)
      end
    end

    def read(feed)
      channel = loading("fetching #{feed.name.downcase}…") { feeds.read(feed) }
      return alert("#{feed.name} did not answer, or what it sent is not a feed. Try again later.") unless channel

      heading = feed.name.upcase[0, 30]
      each_pick(heading, channel.items, empty: 'this feed has nothing in it right now.', right: feed.lang,
                                        label: :title) { |item| show(heading, item, feed) }
    end

    def show(heading, item, feed)
      lines = [*head(item), '', *markdown(item.markdown.empty? ? NO_TEXT : item.markdown), *address(item)]
      return page(heading, lines, right: feed.lang) unless item.link

      page(heading, lines, right: feed.lang, wait: false, room: 2)
      show_qr(item) if actions(['c', 'qr code'], %w[q back]) == 'c'
    end

    def show_qr(item)
      title('SCAN THE ADDRESS', feeds_note)
      pause if qr(item.link)
    end

    # The title and the byline of +item+.
    def head(item)
      byline = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' ')
      lines  = wrap(item.title, WIDTH).map { |l| " #{WH}#{l}#{LG}" }
      byline.empty? ? lines : [*lines, " #{GR}#{byline}#{LG}"]
    end

    def address(item)
      return [] unless item.link

      ['', " #{GR}read it all at:#{LG}", *item.link.scan(/.{1,37}/).map { |w| " #{CY}#{w}#{LG}" }]
    end

    def can_send?
      return true if inbox.open?(caller_key)

      report(:limited, ANSWERS)
      false
    end

    def suggest
      return unless can_send?

      title('SUGGEST A FEED', feeds_note)
      url = prompt('address', hint: 'The admins look at every address before it goes on the list. Return alone: back.',
                              max: InboxService::MAX_FIELD)
      return unless url
      return report(:bad_url, ANSWERS) unless InboxService.url?(url)

      name = prompt('its name', max: InboxService::MAX_FIELD).to_s
      from = prompt('your name', max: InboxService::MAX_FIELD).to_s
      note = prompt('why', max: InboxService::MAX_TEXT).to_s
      report(inbox.suggest(caller: caller_key, url: url, name: name, from: from, note: note), ANSWERS)
    end

    def feedback
      return unless can_send?

      title('WRITE TO THE ADMINS', feeds_note)
      from = prompt('your name', hint: 'A bug, an idea, a word of thanks. Your name, then the message in the editor: ' \
                                       'stop or ← and S sends it, Q goes back.', max: InboxService::MAX_FIELD).to_s
      text = edit(title: 'WRITE TO THE ADMINS', max: InboxService::MAX_TEXT).to_s
      title('WRITE TO THE ADMINS')
      return if text.strip.empty?

      report(inbox.feedback(caller: caller_key, text: text, from: from), ANSWERS)
    end
  end
end
