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

ONLINE   = OnlineService.new(OnlineUsersRepository.new)
MESSAGES = MessageService.new(MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat')))
WIKI     = WikiService.new(WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN']))
GAMES    = GamesService.new(CatalogRepository.new)

MENU_ITEMS = [
  'Messages', 'Post Message', 'Blog Posts',
  'HowTo Guides', 'Game Catalog', 'Online Users',
  'System Info', 'Exit'
].freeze

LEFT_W = 21
CONT_X = 23
CONT_Y = 2

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
  helpers { include BBS::TUI::Helpers }

  init   { init_state }
  chrome { render_chrome }

  page :idle do
    enter { @page_title = 'TELETYPE BBS' }

    render do
      text 'Navigate the menu with ↑↓, select with Enter.',
           x: CONT_X, y: CONT_Y + cont_h / 2, style: THEME[:normal]
    end

    nav :menu, size: MENU_ITEMS.size
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
    enter { @page_title = 'MESSAGES'; load_messages(MESSAGES) }
    render { render_messages }
    nav :scroll, content: -> { @items }, window: -> { cont_h }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :new_msg do
    enter { @page_title = 'POST MESSAGE'; @input = +''; @status = +'' }
    render { render_new_message_form }
    key(:enter) do
      case MESSAGES.post(@username, @input)
      when :empty then @status = 'Message cannot be empty.'
      when :ok    then go :idle
      end
    end
    key(:backspace) { @input.chop! unless @input.empty? }
    key(:escape)    { go :idle }
    printable       { |ch| @input << ch if @input.length < 200 }
  end

  page :blog do
    enter { @page_title = 'BLOG'; load_wiki_list(WIKI, 'blog') }
    render { render_wiki_list }
    nav :list, window: -> { cont_h - 3 }
    key(:enter)  { open_wiki_page(WIKI, back: :blog) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :howto do
    enter { @page_title = 'HOWTO GUIDES'; load_wiki_list(WIKI, 'howto') }
    render { render_wiki_list }
    nav :list, window: -> { cont_h - 3 }
    key(:enter)  { open_wiki_page(WIKI, back: :howto) }
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :page_view do
    render { render_page_view }
    nav :scroll, content: -> { @detail }, window: -> { cont_h - 2 }
    key('q')     { @scroll = 0; go(@prev_page || :idle) }
    key(:escape) { @scroll = 0; go(@prev_page || :idle) }
  end

  page :games do
    enter { @page_title = 'GAME CATALOG'; @items = GAMES.all; @item_sel = 0 }
    render { render_game_card }
    nav :cycle
    key('r')     { reload }
    key('q')     { go :idle }
    key(:escape) { go :idle }
  end

  page :online do
    enter { @page_title = 'ONLINE USERS'; @items = ONLINE.user_list }
    render { render_online_users }
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
    render { render_sysinfo_rows }
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
