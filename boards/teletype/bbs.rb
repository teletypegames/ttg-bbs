# frozen_string_literal: true

require 'bbs'
require 'time'

require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'
require_relative 'lib/repository/last_callers_repository'
require_relative 'lib/repository/profile_repository'
require_relative 'lib/service/online_service'
require_relative 'lib/service/board_service'
require_relative 'lib/service/profile_service'
require_relative 'lib/service/wiki_service'
require_relative 'lib/service/games_service'
require_relative 'lib/service/chat_service'
require_relative 'lib/service/last_callers_service'
require_relative 'lib/ui/windows/system_info_window'
require_relative 'lib/ui/windows/messages_window'
require_relative 'lib/ui/windows/wiki_window'
require_relative 'lib/ui/windows/games_window'
require_relative 'lib/ui/windows/users_window'
require_relative 'lib/ui/windows/chat_window'
require_relative 'lib/ui/windows/bulletin_window'
require_relative 'lib/ui/windows/profile_window'
require_relative 'lib/ui/windows/sysop_window'

ONLINE       = OnlineService.new(OnlineUsersRepository.new)
BOARDS       = BoardService.new(BoardRepository.new(
                ENV.fetch('BOARDS_PATH', 'data/boards'),
                legacy_path: ENV.fetch('MESSAGES_PATH', 'data/messages.dat')))
WIKI         = WikiService.new(WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN']))
GAMES        = GamesService.new(CatalogRepository.new)
CHAT         = ChatService.new
LAST_CALLERS = LastCallersService.new(LastCallersRepository.new(
                ENV.fetch('LAST_CALLERS_PATH', 'data/last_callers.csv')))
PROFILE      = ProfileService.new(ProfileRepository.new(
                ENV.fetch('PROFILE_PATH', 'data/profiles.csv')))

STARTED_AT  = Time.now
SYSOPS      = ENV.fetch('BBS_SYSOPS', '').split(',').map { |s| s.strip.downcase }.reject(&:empty?)
DESKTOP_ART = ENV.fetch('BBS_DESKTOP_ART', 'data/art/teletype.ansi')

SERVICES = {
  online:       ONLINE,
  boards:       BOARDS,
  wiki:         WIKI,
  games:        GAMES,
  chat:         CHAT,
  last_callers: LAST_CALLERS,
  profile:      PROFILE,
  uptime:       STARTED_AT,
}.freeze

MAIN_APP = BBS::Application.define do
  theme BBS::Theme.nortoncommander

  helpers do
    def sysop?
      name = (context[:username] || '').downcase
      SYSOPS.include?(name)
    end
  end

  menubar do
    menu '&File' do
      item '&Bulletin'    do UI::Windows.bulletin(self, services: SERVICES) end
      item '&System Info' do UI::Windows.system_info(self, services: SERVICES) end
      separator
      item 'E&xit', shortcut: 'Alt-X' do :halt end
    end

    menu '&Messages' do
      item '&Boards…',   shortcut: 'F2' do UI::Windows.messages(self, services: SERVICES) end
      item '&New Post…', shortcut: 'F3' do
        board = SERVICES[:boards].boards.first
        UI::Windows.compose_message(self, services: SERVICES, board: board)
      end
    end

    menu '&Files' do
      item '&Blog Posts'   do UI::Windows.wiki(self, services: SERVICES, category: 'blog',  title: 'Blog Posts') end
      item '&HowTo Guides' do UI::Windows.wiki(self, services: SERVICES, category: 'howto', title: 'HowTo Guides') end
      item '&Game Catalog' do UI::Windows.games(self, services: SERVICES) end
    end

    menu '&Users' do
      item '&Online'       do UI::Windows.online_users(self, services: SERVICES) end
      item '&Last Callers' do UI::Windows.last_callers(self, services: SERVICES) end
      item '&Profile…'     do UI::Windows.profile(self, services: SERVICES) end
    end

    menu '&Chat' do
      item '&Open chat', shortcut: 'F4' do UI::Windows.chat(self, services: SERVICES) end
    end

    menu 'S&ysop' do
      item '&Console', shortcut: 'F10' do
        name = (context[:username] || '').downcase
        if SYSOPS.include?(name)
          UI::Windows.sysop_console(self, services: SERVICES)
        else
          BBS::Dialogs.message(self, 'Sysop access denied.', title: ' Sysop ')
        end
      end
    end

    menu '&Help' do
      item '&About' do
        BBS::Dialogs.message(self,
          'Teletype BBS — telnet community board powered by rubbs. ' \
          'Use the top menu (or Alt+letter), Tab to move focus, Esc to close windows.',
          title: ' About ', width: 64)
      end
      item '&Keys' do
        BBS::Dialogs.message(self,
          'Alt+letter — open menu · Tab/Shift-Tab — move focus · Enter — activate · ' \
          'Esc — close window · F1 Help · F2 Boards · F3 Post · F4 Chat · F10 Sysop',
          title: ' Keys ', width: 70)
      end
    end
  end

  status_hint('F1',  'Help')  { BBS::Dialogs.message(self, 'Top menu: Alt+letter — Windows: Tab/Shift-Tab — Close: Esc') }
  status_hint('F2',  'Boards') { UI::Windows.messages(self, services: SERVICES) }
  status_hint('F3',  'Post')   {
    board = SERVICES[:boards].boards.first
    UI::Windows.compose_message(self, services: SERVICES, board: board)
  }
  status_hint('F4',  'Chat')   { UI::Windows.chat(self, services: SERVICES) }
  status_hint('F10', 'Menu')   { menubar.open(0) }
  status_hint('Alt-X', 'Exit') { :halt }

  init do
    art = if File.file?(DESKTOP_ART)
            BBS::Widgets::AnsiArt.from_file(DESKTOP_ART)
          else
            BBS::Widgets::AnsiArt.new(lines: BBS::Widgets::AnsiArt.default_lines)
          end
    art.layout(1, 1, cols, rows - 2)
    add(art)
  end
end

BBS.configure do |c|
  c.mouse        = true
  c.idle_seconds = 600

  c.on_session_end = lambda do |session|
    ONLINE.remove(session.session_id)
    CHAT.unsubscribe(session.session_id)
  end

  c.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success
    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(v) { v.strip.empty? ? 'Anonymous' : v.strip[0...20] }
    call do |ctx|
      ONLINE.add(ctx[:session_id], ctx[:username])
      CHAT.subscribe(ctx[:session_id])
      LAST_CALLERS.record(ctx[:username], ctx[:session_id])
    end
    app MAIN_APP
    say 'Goodbye!', style: :muted
  end
end

BBS.start
