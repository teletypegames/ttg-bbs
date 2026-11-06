# frozen_string_literal: true

module UI
  # The reader on a Commodore 64: PETSCII on a 40×25 screen. A one-key menu,
  # the feeds and their items as numbered lists, an item paged a screenful at
  # a time, and the network's feedback and wall (ttg-common).
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS = [YE, YE, OR, OR, DR].freeze
    ISSUE       = 'vol. i  no. 2327'
    NO_TEXT     = '*(no text in the feed)*'

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
      line 'all the news that fits in 40 columns', color: WH, indent: 2
    end

    main_menu do
      item('f', 'feeds', -> { "#{feeds.list.size} papers to read" }) { feed_list }
      item('w', 'the wall', 'talk about the news') { wall }
      item('s', 'suggest a feed', 'an address for the list') { suggest }
      item('e', 'write to the editors', 'a bug, an idea, a word of thanks') { feedback }
      log_off 'hang up. see you!'
    end

    private

    def feeds_note = "#{feeds.list.size} feeds"

    def feed_list
      each_pick(
        'FEEDS',
        feeds.list,
        empty: 'no feeds are configured.',
        right: feeds_note,
        label: ->(f) { f.lang.empty? ? f.name : "#{f.name} #{GR}#{f.lang}#{LG}" }
      ) do |feed|
        read(feed)
      end
    end

    def read(feed)
      failed  = "#{feed.name} did not answer, or what it sent is not a feed. Try again later."
      channel = loading("fetching #{feed.name.downcase}…", failed: failed) { feeds.read(feed) }

      heading = feed.name.upcase[0, 30]
      each_pick(
        heading,
        channel.items,
        empty: 'this feed has nothing in it right now.',
        right: feed.lang,
        label: :title
      ) { |item| show(heading, item, feed) }
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

    def suggest = TTG::Feedback.open(@session, kind: :feed)

    def feedback = TTG::Feedback.open(@session, kind: :feedback)

    def wall = TTG::Wall.open(@session)
  end
end
