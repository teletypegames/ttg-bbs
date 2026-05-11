# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'

ONLINE   = OnlineUsersRepository.new
MESSAGES = MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogRepository.new

MENU_ITEMS = [
  'Messages', 'Post Message', 'Blog Posts',
  'HowTo Guides', 'Game Catalog', 'Online Users',
  'System Info', 'Exit'
].freeze

# ── Layout ──────────────────────────────────────────────────────────────────

LEFT_W = 21    # left panel outer width
CONT_X = 23    # content start x inside right panel  (LEFT_W + 2)
CONT_Y = 2     # content start y inside panels       (top border + 1)

# ── DOS Navigator color theme ────────────────────────────────────────────────

THEME = {
  bg:       "\e[0;40m",    # black background
  normal:   "\e[0;37m",    # white
  bright:   "\e[1;37m",    # bright white
  border:   "\e[0;36m",    # cyan
  selected: "\e[0;30;46m", # black on cyan  (highlighted menu item)
  header:   "\e[1;36m",    # bright cyan  (section titles)
  label:    "\e[0;33m",    # yellow  (timestamps, labels)
  status:   "\e[0;30;46m", # black on cyan  (bottom status bar)
  input:    "\e[0;33m",    # yellow  (text input)
  success:  "\e[1;32m",    # green
  error:    "\e[1;31m",    # red
  reset:    "\e[0m",
}.freeze

# ── TUI definition ───────────────────────────────────────────────────────────

MAIN_TUI = BBS::TUI.define do
  helpers do
    def tc(style, str) = "#{THEME.fetch(style, THEME[:normal])}#{str}#{THEME[:reset]}"

    def cont_w = term_cols - CONT_X - 1
    def cont_h = term_rows - 4

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
        if    line.empty?                         then line << w
        elsif line.length + 1 + w.length <= width then line << ' ' << w
        else  lines << line.dup; line = +w
        end
      end
      lines << line unless line.empty?
      lines
    end

    def wiki_list_render
      list_h  = cont_h - 3
      visible = @items[@scroll, list_h] || []
      if visible.empty?
        text 'No items found.', x: CONT_X, y: CONT_Y, style: THEME[:normal]
      else
        list visible.map { |p| p.title[0, cont_w - 2] },
             x: CONT_X, y: CONT_Y,
             selected: @item_sel - @scroll,
             style: THEME[:normal], highlight: THEME[:selected]
        if (page = @items[@item_sel])
          hint = page.description.to_s.strip[0, cont_w]
          text hint, x: CONT_X, y: CONT_Y + cont_h - 2, style: THEME[:normal] unless hint.empty?
        end
      end
      text '↑↓ navigate  Enter read  q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
    end

    def scroll_list_up
      return if @item_sel <= 0
      @item_sel -= 1
      @scroll = @item_sel if @item_sel < @scroll
    end

    def scroll_list_down
      return if @item_sel >= @items.size - 1
      @item_sel += 1
      list_h  = cont_h - 3
      @scroll = @item_sel - list_h + 1 if @item_sel >= @scroll + list_h
    end

    def open_wiki_page(back:)
      return unless (page = @items[@item_sel])
      @detail      = wordwrap(WIKI.content(page.id), cont_w)
      @page_title  = page.title
      @page_meta   = "#{fmt_date(page.created_at)}  #{WIKI.page_url(page.locale, page.path)}"
      @prev_page   = back
      @scroll      = 0
      go :page_view
    end
  end

  init do
    @menu_sel    = 0
    @page_title  = 'TELETYPE BBS'
    @items       = []
    @item_sel    = 0
    @scroll      = 0
    @detail      = []
    @page_meta   = +''
    @input       = +''
    @status      = +''
    @prev_page   = nil
  end

  chrome do
    screen_fill bg: :black

    panel_h = term_rows - 1

    box x: 1,          y: 1, w: LEFT_W,             h: panel_h,
        style: THEME[:border], bg: :black

    box x: LEFT_W + 1, y: 1, w: term_cols - LEFT_W, h: panel_h,
        title: " #{@page_title}  │  #{@username}  │  #{ONLINE.count} online ",
        style: THEME[:border], bg: :black

    list MENU_ITEMS.map { |i| i[0, LEFT_W - 4] },
         x: 2, y: CONT_Y,
         selected: @menu_sel,
         style: THEME[:normal], highlight: THEME[:selected]

    bar y: term_rows,
        content: "  \e[1;37;46m↑↓\e[0;30;46m Navigate  \e[1;37;46mEnter\e[0;30;46m Select  " \
                 "\e[1;37;46mQ\e[0;30;46m Back  \e[1;37;46mR\e[0;30;46m Refresh",
        style: THEME[:status]
  end

  # ── Pages ───────────────────────────────────────────────────────────────────

  page :idle do
    enter { @page_title = 'TELETYPE BBS' }

    render do
      text 'Navigate the menu with ↑↓, select with Enter.',
           x: CONT_X, y: CONT_Y + cont_h / 2, style: THEME[:normal]
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
      @page_title = 'MESSAGES'
      @items  = MESSAGES.last(30).map { |m| "#{tc(:label, m.timestamp)} #{tc(:bright, m.username)}: #{m.text}" }
      @scroll = 0
    end

    render do
      (@items[@scroll, cont_h] || []).each_with_index do |line, i|
        text line[0, cont_w], x: CONT_X, y: CONT_Y + i
      end
      text "#{@items.size} msg(s)  ↑↓ scroll  q back",
           x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
    end

    key(:up)     { @scroll = [@scroll - 1, 0].max }
    key(:down)   { @scroll = [@scroll + 1, [@items.size - cont_h, 0].max].min }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :new_msg do
    enter { @page_title = 'POST MESSAGE'; @input = +''; @status = +'' }

    render do
      text 'Type your message and press Enter.  Esc cancels.',
           x: CONT_X, y: CONT_Y, style: THEME[:normal]
      text "#{tc(:bright, @username)}: #{tc(:input, @input)}_",
           x: CONT_X, y: CONT_Y + 2
      unless @status.empty?
        text @status, x: CONT_X, y: CONT_Y + 4,
             style: @status.start_with?('Sent') ? THEME[:success] : THEME[:error]
      end
    end

    key(:enter) do
      if @input.strip.empty?
        @status = 'Message cannot be empty.'
      else
        MESSAGES.append(@username, @input.strip[0...200])
        go :idle
      end
    end
    key(:backspace) { @input.chop! unless @input.empty? }
    key(:escape)    { go :idle }
    printable       { |ch| @input << ch if @input.length < 200 }
  end

  page :blog do
    enter  { @page_title = 'BLOG'; @items = WIKI.list('blog'); @item_sel = 0; @scroll = 0 }
    render { wiki_list_render }
    key(:up)     { scroll_list_up }
    key(:down)   { scroll_list_down }
    key(:enter)  { open_wiki_page(back: :blog) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :howto do
    enter  { @page_title = 'HOWTO'; @items = WIKI.list('howto'); @item_sel = 0; @scroll = 0 }
    render { wiki_list_render }
    key(:up)     { scroll_list_up }
    key(:down)   { scroll_list_down }
    key(:enter)  { open_wiki_page(back: :howto) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :page_view do
    render do
      text @page_meta[0, cont_w], x: CONT_X, y: CONT_Y, style: THEME[:normal]
      (@detail[@scroll, cont_h - 2] || []).each_with_index do |l, i|
        text l[0, cont_w], x: CONT_X, y: CONT_Y + 2 + i, style: THEME[:normal]
      end
      text "#{@scroll + 1}/#{@detail.size}  ↑↓ scroll  q back",
           x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
    end

    key(:up)     { @scroll = [@scroll - 1, 0].max }
    key(:down)   { @scroll = [@scroll + 1, [@detail.size - (cont_h - 2), 0].max].min }
    key('q')     { @scroll = 0; go(@prev_page || :idle) }
    key(:escape) { @scroll = 0; go(@prev_page || :idle) }
  end

  page :games do
    enter { @page_title = 'GAME CATALOG'; @items = CATALOG.fetch; @item_sel = 0 }

    render do
      if @items.empty?
        text 'No games found.', x: CONT_X, y: CONT_Y, style: THEME[:normal]
      else
        game  = @items[@item_sel]
        links = game.external_links

        text "#{@item_sel + 1}/#{@items.size}  #{game.title}"[0, cont_w],
             x: CONT_X, y: CONT_Y, style: THEME[:bright]
        text "#{game.platform}  ·  #{game.author}"[0, cont_w],
             x: CONT_X, y: CONT_Y + 1, style: THEME[:normal]

        story_rows = cont_h - 4 - links.size
        wordwrap(game.story, cont_w).first(story_rows).each_with_index do |l, i|
          text l, x: CONT_X, y: CONT_Y + 3 + i, style: THEME[:normal]
        end

        link_y = CONT_Y + cont_h - links.size
        links.each_with_index do |lnk, i|
          text "#{tc(:label, lnk[:label])}  #{lnk[:url]}"[0, cont_w],
               x: CONT_X, y: link_y + i
        end

        text '↑↓ navigate  q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
      end
    end

    key(:up)     { @item_sel = (@item_sel - 1) % @items.size if @items.any? }
    key(:down)   { @item_sel = (@item_sel + 1) % @items.size if @items.any? }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :online do
    enter { @page_title = 'ONLINE USERS'; @items = ONLINE.snapshot.sort.map { |_, name| name } }

    render do
      @items.each_with_index do |uname, i|
        you  = uname == @username ? tc(:normal, ' ← you') : ''
        text tc(:bright, uname) + you, x: CONT_X, y: CONT_Y + i
      end
      text "#{@items.size} user(s) online  q back",
           x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
    end

    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :sysinfo do
    enter do
      @page_title = 'SYSTEM INFO'
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
      @items.each_with_index do |row, i|
        text row[0, cont_w], x: CONT_X, y: CONT_Y + i, style: THEME[:normal]
      end
      text 'q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
    end

    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  start :idle
end

# ── App config ───────────────────────────────────────────────────────────────

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
