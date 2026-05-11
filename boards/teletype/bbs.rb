# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'

include BBS::Color

ONLINE   = OnlineUsersRepository.new
MESSAGES = MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogRepository.new

MENU_ITEMS = [
  'Messages', 'Post Message', 'Blog Posts',
  'HowTo Guides', 'Game Catalog', 'Online Users',
  'System Info', 'Exit'
].freeze

SEP_X  = 21
CONT_X = 23
CONT_Y = 3

MAIN_TUI = BBS::TUI.define do
  helpers do
    def cont_w = term_cols - CONT_X - 1
    def cont_h = term_rows - CONT_Y - 4

    def fmt_date(iso)
      Time.parse(iso.to_s).strftime('%Y-%m-%d')
    rescue
      iso.to_s
    end

    def wordwrap(text, width)
      words = text.to_s
                  .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
                  .gsub(/[#*_`~>|\\]/, '')
                  .gsub(/\r?\n+/, ' ')
                  .strip
                  .split
      lines, line = [], +''
      words.each do |w|
        if    line.empty?                        then line << w
        elsif line.length + 1 + w.length <= width then line << ' ' << w
        else  lines << line.dup; line = +w
        end
      end
      lines << line unless line.empty?
      lines
    end

    def wiki_list_render(color:, title:)
      text c(color, title), x: CONT_X, y: CONT_Y
      if @items.empty?
        text c(:gray, 'No items found.'), x: CONT_X, y: CONT_Y + 2
        return
      end
      list_h  = cont_h - 5
      visible = @items[@scroll, list_h] || []
      list visible.map { |p| p.title[0, cont_w - 2] },
           x: CONT_X, y: CONT_Y + 2,
           selected: @item_sel - @scroll, style: :gray, highlight: :white
      if (page = @items[@item_sel])
        hint = page.description.to_s.strip[0, cont_w]
        text c(:gray, hint), x: CONT_X, y: CONT_Y + cont_h - 2 unless hint.empty?
      end
      text c(:gray, '↑↓ navigate  Enter read  q back'), x: CONT_X, y: CONT_Y + cont_h
    end

    def scroll_list_up
      return if @item_sel <= 0
      @item_sel -= 1
      @scroll = @item_sel if @item_sel < @scroll
    end

    def scroll_list_down
      return if @item_sel >= @items.size - 1
      @item_sel += 1
      list_h  = cont_h - 5
      @scroll = @item_sel - list_h + 1 if @item_sel >= @scroll + list_h
    end

    def open_wiki_page(back:)
      return unless (page = @items[@item_sel])
      @detail      = wordwrap(WIKI.content(page.id), cont_w)
      @page_header = page.title
      @page_meta   = "#{fmt_date(page.created_at)}  #{WIKI.page_url(page.locale, page.path)}"
      @prev_page   = back
      @scroll      = 0
      go :page_view
    end
  end

  init do
    @menu_sel    = 0
    @items       = []
    @item_sel    = 0
    @scroll      = 0
    @detail      = []
    @page_header = ''
    @page_meta   = ''
    @input       = ''
    @status      = ''
    @prev_page   = nil
  end

  chrome do
    bar y: 1,
        content: "  TELETYPE BBS  │  #{@username}  │  #{ONLINE.count} online",
        style: :success
    list MENU_ITEMS.map { |i| i[0, 15] }, x: 2, y: CONT_Y,
         selected: @menu_sel, style: :gray, highlight: :white
    (CONT_Y..CONT_Y + cont_h).each { |r| text c(:gray, '│'), x: SEP_X, y: r }
    bar y: term_rows,
        content: '  ↑↓ Navigate  Enter Select  q Back/Quit  r Refresh',
        style: :muted
  end

  # ── Pages ───────────────────────────────────────────────────────────────────

  page :idle do
    render do
      text c(:gray, 'Navigate with ↑↓, select with Enter'),
           x: CONT_X, y: CONT_Y + cont_h / 2
    end

    key(:up)    { @menu_sel = (@menu_sel - 1) % MENU_ITEMS.size }
    key(:down)  { @menu_sel = (@menu_sel + 1) % MENU_ITEMS.size }
    key(:enter) do
      case MENU_ITEMS[@menu_sel]
      when 'Messages'     then go :messages
      when 'Post Message' then go :new_msg
      when 'Blog Posts'   then go :blog
      when 'HowTo Guides' then go :howto
      when 'Game Catalog' then go :games
      when 'Online Users' then go :online
      when 'System Info'  then go :sysinfo
      when 'Exit'         then :halt
      end
    end
    key('q')     { :halt }
    key(:escape) { :halt }
  end

  page :messages do
    enter do
      @items  = MESSAGES.last(30).map { |m| "#{c(:yellow, m.timestamp)} #{c(:white, m.username)}: #{m.text}" }
      @scroll = 0
    end

    render do
      text c(:cyan, '── Message Board ──'), x: CONT_X, y: CONT_Y
      (@items[@scroll, cont_h - 2] || []).each_with_index do |line, i|
        text line[0, cont_w], x: CONT_X, y: CONT_Y + 2 + i
      end
      text c(:gray, "#{@items.size} msg(s)  ↑↓ scroll  q back"),
           x: CONT_X, y: CONT_Y + cont_h
    end

    key(:up)     { @scroll = [@scroll - 1, 0].max }
    key(:down)   { @scroll = [@scroll + 1, [@items.size - (cont_h - 2), 0].max].min }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :new_msg do
    enter { @input = ''; @status = '' }

    render do
      text c(:cyan,  '── Post Message ──'), x: CONT_X, y: CONT_Y
      text c(:gray,  'Type message and press Enter.  Esc cancels.'), x: CONT_X, y: CONT_Y + 2
      text c(:white, "#{@username}: #{@input}_"), x: CONT_X, y: CONT_Y + 4
      text c(:green, @status), x: CONT_X, y: CONT_Y + 6 unless @status.empty?
    end

    key(:enter) do
      if @input.strip.empty?
        @status = 'Message cannot be empty.'
      else
        MESSAGES.append(@username, @input.strip[0...200])
        @status = 'Sent!'
        @input  = ''
      end
    end
    key(:backspace) { @input.chop! unless @input.empty? }
    key(:escape)    { go :idle }
    printable       { |ch| @input << ch if @input.length < 200 }
  end

  page :blog do
    enter  { @items = WIKI.list('blog'); @item_sel = 0; @scroll = 0 }
    render { wiki_list_render(color: :blue, title: '── Blog Posts ──') }
    key(:up)     { scroll_list_up }
    key(:down)   { scroll_list_down }
    key(:enter)  { open_wiki_page(back: :blog) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :howto do
    enter  { @items = WIKI.list('howto'); @item_sel = 0; @scroll = 0 }
    render { wiki_list_render(color: :magenta, title: '── HowTo Guides ──') }
    key(:up)     { scroll_list_up }
    key(:down)   { scroll_list_down }
    key(:enter)  { open_wiki_page(back: :howto) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :page_view do
    render do
      text c(:cyan, @page_header[0, cont_w]), x: CONT_X, y: CONT_Y
      text c(:gray, @page_meta[0, cont_w]),   x: CONT_X, y: CONT_Y + 1
      (@detail[@scroll, cont_h - 3] || []).each_with_index do |l, i|
        text c(:gray, l[0, cont_w]), x: CONT_X, y: CONT_Y + 3 + i
      end
      text c(:gray, "#{@scroll + 1}/#{@detail.size}  ↑↓ scroll  q back"),
           x: CONT_X, y: CONT_Y + cont_h
    end

    key(:up)     { @scroll = [@scroll - 1, 0].max }
    key(:down)   { @scroll = [@scroll + 1, [@detail.size - (cont_h - 3), 0].max].min }
    key('q')     { @scroll = 0; go(@prev_page || :idle) }
    key(:escape) { @scroll = 0; go(@prev_page || :idle) }
  end

  page :games do
    enter { @items = CATALOG.fetch; @item_sel = 0 }

    render do
      text c(:cyan, '── Game Catalog ──'), x: CONT_X, y: CONT_Y
      if @items.empty?
        text c(:gray, 'No games found.'), x: CONT_X, y: CONT_Y + 2
      else
        game = @items[@item_sel]
        text c(:white, "#{@item_sel + 1}/#{@items.size}  #{game.title}"[0, cont_w]),
             x: CONT_X, y: CONT_Y + 1
        text c(:gray,  "#{game.platform}  #{game.author}"[0, cont_w]),
             x: CONT_X, y: CONT_Y + 2
        wordwrap(game.desc.to_s, cont_w).first(cont_h - 10).each_with_index do |l, i|
          text c(:gray, l), x: CONT_X, y: CONT_Y + 4 + i
        end
        badges = []
        badges << c(:green,   '[▶ Play]')     unless game.play_path.empty?
        badges << c(:yellow,  '[⬇ Download]') unless game.download_path.empty?
        badges << c(:blue,    '[Source]')     unless game.source_path.empty?
        badges << c(:magenta, '[Docs]')       unless game.docs_path.empty?
        text badges.join('  '), x: CONT_X, y: CONT_Y + cont_h - 5
        text c(:gray, '↑↓ navigate  q back'), x: CONT_X, y: CONT_Y + cont_h
      end
    end

    key(:up)     { @item_sel = (@item_sel - 1) % @items.size if @items.any? }
    key(:down)   { @item_sel = (@item_sel + 1) % @items.size if @items.any? }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :online do
    enter { @items = ONLINE.snapshot.sort.map { |_, name| name } }

    render do
      text c(:yellow, '── Online Users ──'), x: CONT_X, y: CONT_Y
      @items.each_with_index do |uname, i|
        you = uname == @username ? c(:gray, ' ← you') : ''
        text c(:white, uname) + you, x: CONT_X, y: CONT_Y + 2 + i
      end
      text c(:gray, "#{@items.size} user(s) online  q back"),
           x: CONT_X, y: CONT_Y + cont_h
    end

    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :sysinfo do
    enter do
      @items = [
        "Online users  #{ONLINE.count}",
        "Messages      #{MESSAGES.count}",
        "Wiki          https://wiki.teletypegames.org",
        "Games API     https://teletypegames.org",
        "Platform      #{RUBY_PLATFORM}",
        "Ruby          #{RUBY_VERSION}"
      ]
    end

    render do
      text c(:magenta, '── System Info ──'), x: CONT_X, y: CONT_Y
      @items.each_with_index do |row, i|
        text c(:gray, row[0, cont_w]), x: CONT_X, y: CONT_Y + 2 + i
      end
      text c(:gray, 'q back'), x: CONT_X, y: CONT_Y + cont_h
    end

    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  start :idle
end

BBS.configure do |c|
  c.on_session_end = ->(session) { ONLINE.remove(session.session_id) }

  c.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success

    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(v) { v.strip.empty? ? 'Anonymous' : v.strip[0...20] }

    call { |ctx| ONLINE.add(ctx[:session_id], ctx[:username]) }

    tui MAIN_TUI

    say 'Goodbye!', style: :muted
  end
end

BBS.start
