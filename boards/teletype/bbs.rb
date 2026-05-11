# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'
require_relative 'lib/page/helpers'
require_relative 'lib/page/idle_page'
require_relative 'lib/page/messages_page'
require_relative 'lib/page/new_msg_page'
require_relative 'lib/page/wiki_list_page'
require_relative 'lib/page/page_view_page'
require_relative 'lib/page/games_page'
require_relative 'lib/page/online_page'
require_relative 'lib/page/sysinfo_page'

ONLINE   = OnlineUsersRepository.new
MESSAGES = MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogRepository.new

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
  normal:   "\e[0;37m",
  bright:   "\e[1;37m",
  border:   "\e[0;36m",
  selected: "\e[0;30;46m",
  header:   "\e[1;36m",
  label:    "\e[0;33m",
  status:   "\e[0;30;46m",
  input:    "\e[0;33m",
  success:  "\e[1;32m",
  error:    "\e[1;31m",
  reset:    "\e[0m",
}.freeze

MAIN_TUI = BBS::TUI.define do
  helpers { include TUIHelpers }

  init do
    @menu_sel   = 0
    @page_title = 'TELETYPE BBS'
    @items      = []
    @item_sel   = 0
    @scroll     = 0
    @detail     = []
    @page_meta  = +''
    @input      = +''
    @status     = +''
    @prev_page  = nil
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

  IdlePage.configure(self)
  MessagesPage.configure(self)
  NewMsgPage.configure(self)
  WikiListPage.configure(self, :blog,  category: 'blog',  title: 'BLOG')
  WikiListPage.configure(self, :howto, category: 'howto', title: 'HOWTO GUIDES')
  PageViewPage.configure(self)
  GamesPage.configure(self)
  OnlinePage.configure(self)
  SysinfoPage.configure(self)

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
