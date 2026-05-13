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
require_relative 'lib/ui/formatters'

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
  uptime:       STARTED_AT
}.freeze

MAIN_APP = BBS::Application.define do
  theme BBS::Theme.neumanntronics
  services SERVICES

  helpers do
    def sysop?
      name = (context[:username] || '').downcase
      SYSOPS.include?(name)
    end
  end

  # ── Windows ────────────────────────────────────────────────────────────────

  window :bulletin, type: :info do |w|
    w.title  ' Welcome '
    w.width  70
    w.height 17
    w.body do |ctx|
      UI::Formatters::Bulletin.body(
        username:       ctx[:username] || 'Anonymous',
        online_count:   ctx[:online].count,
        total_messages: ctx[:boards].total_count,
        recent_callers: ctx[:last_callers].recent(3)
      )
    end
    w.button label: '&Continue', primary: true, cancel: true
  end

  window :system_info, type: :info do |w|
    w.title  ' System Info '
    w.width  60
    w.height 14
    w.body do |ctx|
      rows = [
        ['Online users', ctx[:online].count.to_s],
        ['Messages',     ctx[:boards].total_count.to_s],
        ['Boards',       ctx[:boards].boards.size.to_s],
        ['Wiki',         'https://wiki.teletypegames.org'],
        ['Games API',    'https://teletypegames.org'],
        ['Platform',     RUBY_PLATFORM],
        ['Ruby',         RUBY_VERSION],
        ['Uptime',       UI::Formatters::SystemInfo.format_uptime(ctx[:uptime])]
      ]
      [{ kv: rows, label_width: 15 }]
    end
  end

  window :messages, type: :master_detail do |w|
    w.title         ' Message Boards '
    w.list_width    20
    w.empty_message '  (no boards configured)'
    w.items         { |ctx| ctx[:boards].boards }
    w.item_label    { |board, _ctx| board.title }
    w.render_detail do |board, width, ctx|
      UI::Formatters::Board.lines(ctx[:boards].messages(board.id, 100), board.title, width)
    end
    w.action label: '&New', align: :left do |window, ctx|
      board = window.list_widget.selected_item
      ctx[:app].open_window(:compose_message, board: board,
                            on_posted: -> { window.reload_detail })
      :keep
    end
    w.action label: '&Refresh', align: :left do |window, _ctx|
      window.reload_detail
      :keep
    end
  end

  window :compose_message, type: :form do |w|
    w.title        { |ctx| ctx[:board] ? " Post to #{ctx[:board].title} " : ' Compose ' }
    w.width        { |ctx| [ctx[:app].cols - 8, 70].min }
    w.height       14
    w.hint         { |ctx| "From: #{ctx[:username] || 'Anonymous'} — Ctrl-Enter sends" }
    w.submit_label '&Send'
    w.cancel_label '&Cancel'
    w.field :body, type: :textarea, max_length: 1000
    w.on_submit do |values, form, ctx|
      if ctx[:board].nil?
        form.error('Select a board first.')
        :keep
      else
        case ctx[:boards].post(ctx[:board].id, ctx[:username] || 'Anonymous', values[:body])
        when :empty
          form.error('Message cannot be empty.')
          :keep
        else
          ctx[:on_posted]&.call
          :close
        end
      end
    end
  end

  window :wiki, type: :master_detail do |w|
    w.title         { |ctx| " #{ctx[:title]} " }
    w.list_width    { |ctx| [32, ctx[:app].cols / 3].max }
    w.empty_message '  (no pages found)'
    w.close_button  false
    w.items         { |ctx| ctx[:wiki].list(ctx[:category]) }
    w.item_label    { |page, _ctx| page.title }
    w.render_detail do |page, width, ctx|
      text = ctx[:wiki].content(page.id)
      BBS::Markdown.to_lines(text, width: width - 1, theme: ctx[:app].theme)
    end
    w.bottom_meta do |page, ctx|
      "#{page.created_at.to_s[0, 10]}  #{ctx[:wiki].page_url(page.locale, page.path)}"
    end
  end

  window :games, type: :master_detail do |w|
    w.title         ' Game Catalog '
    w.list_width    30
    w.empty_message '  (no games)'
    w.items         { |ctx| ctx[:games].all }
    w.item_label    { |game, _ctx| game.title }
    w.render_detail { |game, width, _ctx| UI::Formatters::Game.card(game, width) }
  end

  window :online_users, type: :info do |w|
    w.title  ' Online Users '
    w.width  50
    w.scroll true
    w.height { |ctx| [ctx[:online].user_list.size + 6, 10].max }
    w.body   { |ctx| UI::Formatters::Users.online_list(ctx[:online].user_list, ctx[:username]) }
  end

  window :last_callers, type: :info do |w|
    w.title  ' Last Callers '
    w.width  64
    w.scroll true
    w.height { |ctx| [ctx[:last_callers].recent(15).size + 6, 10].max }
    w.body   { |ctx| UI::Formatters::Users.last_callers_list(ctx[:last_callers].recent(15)) }
  end

  window :chat, type: :stream do |w|
    w.title       ' Live Chat '
    w.placeholder 'Type a message and press Enter…'
    w.initial_lines do |ctx|
      ctx[:chat].history.map { |line| UI::Formatters::Chat.line(line) }
    end
    w.on_submit do |text, _app, ctx|
      ctx[:chat].broadcast(ctx[:username] || 'Anonymous', text.strip)
    end
    w.on_poll do |app_, ctx|
      ctx[:chat].drain(app_.session_id).map { |line| UI::Formatters::Chat.line(line) }
    end
  end

  window :profile, type: :form do |w|
    w.title  { |ctx| " Profile — #{ctx[:username] || 'Anonymous'} " }
    w.width  64
    w.height 14
    w.prefill do |ctx|
      existing = ctx[:profile].find(ctx[:username] || 'Anonymous') || {}
      {
        signature: existing['signature'].to_s,
        location:  existing['location'].to_s,
        homepage:  existing['homepage'].to_s,
        notes:     existing['notes'].to_s
      }
    end
    w.field :signature, label: 'Signature'
    w.field :location,  label: 'Location'
    w.field :homepage,  label: 'Homepage'
    w.field :notes,     label: 'Notes'
    w.on_submit do |values, _form, ctx|
      ctx[:profile].update(ctx[:username] || 'Anonymous', **values)
      BBS::Dialogs.message(ctx[:app], 'Profile saved.', title: ' Saved ')
      :close
    end
  end

  window :sysop_console, type: :info do |w|
    w.title  ' Sysop Console '
    w.width  70
    w.height 18
    w.scroll true
    w.body do |ctx|
      UI::Formatters::Sysop.console_body(
        username:         ctx[:username],
        online_count:     ctx[:online].count,
        total_messages:   ctx[:boards].total_count,
        chat_subscribers: ctx[:chat].subscriber_count,
        online_users:     ctx[:online].user_list,
        recent_callers:   ctx[:last_callers].recent(5)
      )
    end
    w.button label: '&Broadcast', align: :left do |_window, ctx|
      BBS::Dialogs.input(ctx[:app], prompt: 'Sysop broadcast message:',
                         title: ' Broadcast ', width: 64,
                         on_submit: lambda do |text|
                           next if text.strip.empty?
                           ctx[:chat].broadcast("[SYSOP] #{ctx[:username]}", text.strip)
                         end)
      :keep
    end
    w.button label: '&Close', cancel: true
  end

  # ── Menubar ────────────────────────────────────────────────────────────────

  menubar do
    menu '&File' do
      item '&Bulletin'    do open_window(:bulletin) end
      item '&System Info' do open_window(:system_info) end
      separator
      item 'E&xit', shortcut: 'Alt-X' do :halt end
    end

    menu '&Messages' do
      item '&Boards…',   shortcut: 'F2' do open_window(:messages) end
      item '&New Post…', shortcut: 'F3' do
        board = SERVICES[:boards].boards.first
        if board
          open_window(:compose_message, board: board)
        else
          BBS::Dialogs.message(self, 'Select a board first.', title: ' Compose ')
        end
      end
    end

    menu '&Files' do
      item '&Blog Posts'   do open_window(:wiki, category: 'blog',  title: 'Blog Posts') end
      item '&HowTo Guides' do open_window(:wiki, category: 'howto', title: 'HowTo Guides') end
      item '&Game Catalog' do open_window(:games) end
    end

    menu '&Users' do
      item '&Online'       do open_window(:online_users) end
      item '&Last Callers' do open_window(:last_callers) end
      item '&Profile…'     do open_window(:profile) end
    end

    menu '&Chat' do
      item '&Open chat', shortcut: 'F4' do open_window(:chat) end
    end

    menu 'S&ysop' do
      item '&Console', shortcut: 'F10' do
        if sysop?
          open_window(:sysop_console)
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
  status_hint('F2',  'Boards') { open_window(:messages) }
  status_hint('F3',  'Post')   {
    board = SERVICES[:boards].boards.first
    if board
      open_window(:compose_message, board: board)
    else
      BBS::Dialogs.message(self, 'Select a board first.', title: ' Compose ')
    end
  }
  status_hint('F4',  'Chat')   { open_window(:chat) }
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
