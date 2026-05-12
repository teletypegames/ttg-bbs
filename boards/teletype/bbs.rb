# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'
require_relative 'lib/service/online_service'
require_relative 'lib/service/message_service'
require_relative 'lib/service/wiki_service'
require_relative 'lib/service/games_service'
require_relative 'lib/tui/helpers'

ONLINE   = OnlineService.new(OnlineUsersRepository.new)
MESSAGES = MessageService.new(MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat')))
WIKI     = WikiService.new(WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN']))
GAMES    = GamesService.new(CatalogRepository.new)

MENU_ITEMS = [
  'Messages', 'Post Message', 'Blog Posts',
  'HowTo Guides', 'Game Catalog', 'Online Users',
  'System Info', 'Exit'
].freeze

LEFT_WIDTH = 21
CONTENT_X  = 23
CONTENT_Y  = 2

THEME = {
  bg:       "\e[0;40m",
  normal:   "\e[0;33m",
  bright:   "\e[1;33m",
  border:   "\e[0;33m",
  selected: "\e[0;30;43m",
  header:   "\e[1;33m",
  label:    "\e[2;33m",
  status:   "\e[0;30;43m",
  input:    "\e[1;33m",
  success:  "\e[1;32m",
  error:    "\e[1;31m",
  reset:    "\e[0m",
}.freeze

MAIN_TUI = BBS::TUI.define do
  helpers { include TUIHelpers }

  init do
    @menu_selection = 0
    @page_title     = 'TELETYPE BBS'
    @items          = []
    @item_selection = 0
    @scroll         = 0
    @detail         = []
    @page_metadata  = +''
    @input          = +''
    @status         = +''
    @previous_page  = nil
    @modal          = nil
  end

  chrome { render_chrome }

  page :idle do
    enter { @page_title = 'TELETYPE BBS'; @modal = nil }

    render do
      text 'Navigate the menu with ↑↓, select with Enter.',
           x: CONTENT_X, y: CONTENT_Y + content_height / 2, style: THEME[:normal]

      if @modal == :sysinfo
        float title: ' SYSTEM INFO ', width: 56, height: 10,
              style: THEME[:border], background: :black do |fx, fy, fw, _|
          [
            "Online users  #{ONLINE.count}",
            "Messages      #{MESSAGES.count}",
            "Wiki          https://wiki.teletypegames.org",
            "Games API     https://teletypegames.org",
            "Platform      #{RUBY_PLATFORM}",
            "Ruby          #{RUBY_VERSION}",
          ].each_with_index do |row, index|
            text row[0, fw], x: fx, y: fy + index, style: THEME[:normal]
          end
          text 'ESC  close', x: fx, y: fy + 7, style: THEME[:label]
        end
      elsif @modal == :new_msg
        float title: ' POST MESSAGE ', width: 62, height: 9,
              style: THEME[:border], background: :black do |fx, fy, fw, _|
          text 'Type your message and press Enter.  Esc cancels.',
               x: fx, y: fy, style: THEME[:normal]
          text "#{themed_color(:bright, @username)}: #{themed_color(:input, @input)}_",
               x: fx, y: fy + 2
          text @status, x: fx, y: fy + 4, style: THEME[:error] unless @status.empty?
          text "#{@input.length}/200  ESC cancel",
               x: fx, y: fy + 6, style: THEME[:label]
        end
      end
    end

    nav :menu, size: MENU_ITEMS.size
    key(:enter) do
      if @modal == :new_msg
        case MESSAGES.post(@username, @input)
        when :empty then @status = 'Message cannot be empty.'
        when :ok    then @modal = nil
        end
      elsif @modal.nil?
        case MENU_ITEMS[@menu_selection]
        when 'Messages'     then go :messages
        when 'Post Message' then @modal = :new_msg; @input = +''; @status = +''
        when 'Blog Posts'   then go :blog
        when 'HowTo Guides' then go :howto
        when 'Game Catalog' then go :games
        when 'Online Users' then go :online
        when 'System Info'  then @modal = :sysinfo
        when 'Exit'         then :halt
        end
      end
    end
    key(:backspace) { @input.chop! if @modal == :new_msg && !@input.empty? }
    key('q')        { @modal ? @modal = nil : :halt }
    key(:escape)    { @modal ? @modal = nil : :halt }
    printable       { |ch| @input << ch if @modal == :new_msg && @input.length < 200 }
  end

  page :messages do
    enter do
      @page_title = 'MESSAGES'
      @items      = MESSAGES.recent(30)
      @scroll     = 0
    end
    render { render_messages }
    nav :scroll, content: -> { @items }, window: -> { content_height }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :blog do
    enter do
      @page_title     = 'BLOG'
      @items          = WIKI.list('blog')
      @item_selection = 0
      @scroll         = 0
    end
    render { render_wiki_list }
    nav :list, window: -> { content_height - 3 }
    key(:enter) do
      next unless (wiki_page = @items[@item_selection])
      @detail        = wordwrap(WIKI.content(wiki_page.id), content_width)
      @page_title    = wiki_page.title
      @page_metadata = "#{format_date(wiki_page.created_at)}  " \
                       "#{WIKI.page_url(wiki_page.locale, wiki_page.path)}"
      @previous_page = :blog
      @scroll        = 0
      go :page_view
    end
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :howto do
    enter do
      @page_title     = 'HOWTO GUIDES'
      @items          = WIKI.list('howto')
      @item_selection = 0
      @scroll         = 0
    end
    render { render_wiki_list }
    nav :list, window: -> { content_height - 3 }
    key(:enter) do
      next unless (wiki_page = @items[@item_selection])
      @detail        = wordwrap(WIKI.content(wiki_page.id), content_width)
      @page_title    = wiki_page.title
      @page_metadata = "#{format_date(wiki_page.created_at)}  " \
                       "#{WIKI.page_url(wiki_page.locale, wiki_page.path)}"
      @previous_page = :howto
      @scroll        = 0
      go :page_view
    end
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :page_view do
    render { render_page_view }
    nav :scroll, content: -> { @detail }, window: -> { content_height - 2 }
    key('q')     { @scroll = 0; go(@previous_page || :idle) }
    key(:escape) { @scroll = 0; go(@previous_page || :idle) }
  end

  page :games do
    enter do
      @page_title     = 'GAME CATALOG'
      @items          = GAMES.all
      @item_selection = 0
    end
    render { render_game_card }
    nav :cycle
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :online do
    enter do
      @page_title = 'ONLINE USERS'
      @items      = ONLINE.user_list
    end
    render { render_online_users }
    key('r')     { reload }
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
        transform: ->(value) { value.strip.empty? ? 'Anonymous' : value.strip[0...20] }
    call { |ctx| ONLINE.add(ctx[:session_id], ctx[:username]) }
    tui MAIN_TUI
    say 'Goodbye!', style: :muted
  end
end

BBS.start
