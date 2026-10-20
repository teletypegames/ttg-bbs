# frozen_string_literal: true

require 'bbs'
require 'time'

require_relative 'lib/domain/repository/online_users_repository'
require_relative 'lib/domain/repository/board_repository'
require_relative 'lib/domain/repository/wiki_repository'
require_relative 'lib/domain/repository/catalog_repository'
require_relative 'lib/domain/repository/last_callers_repository'
require_relative 'lib/domain/repository/profile_repository'
require_relative 'lib/domain/repository/account_repository'
require_relative 'lib/domain/repository/site_repository'
require_relative 'lib/domain/service/online_service'
require_relative 'lib/domain/service/board_service'
require_relative 'lib/domain/service/profile_service'
require_relative 'lib/domain/service/wiki_service'
require_relative 'lib/domain/service/games_service'
require_relative 'lib/domain/service/chat_service'
require_relative 'lib/domain/service/last_callers_service'
require_relative 'lib/domain/service/account_service'
require_relative 'lib/domain/service/site_service'
require_relative 'lib/domain/service/discord_notifier'
require_relative 'lib/bbs/ui/formatters'

online_service       = OnlineService.new(OnlineUsersRepository.new)
board_service        = BoardService.new(BoardRepository.new(
                         ENV.fetch('BOARDS_PATH', 'data/boards'),
                         legacy_path: ENV.fetch('MESSAGES_PATH', 'data/messages.dat')))
wiki_service         = WikiService.new(WikiRepository.new)
games_service        = GamesService.new(CatalogRepository.new)
chat_service         = ChatService.new
last_callers_service = LastCallersService.new(LastCallersRepository.new(
                         ENV.fetch('LAST_CALLERS_PATH', 'data/last_callers.csv')))
profile_service      = ProfileService.new(ProfileRepository.new(
                         ENV.fetch('PROFILE_PATH', 'data/profiles.csv')))
site_service         = SiteService.new(SiteRepository.new)
discord              = DiscordNotifier.new(ENV['BBS_DISCORD_WEBHOOK'])

STARTED_AT  = Time.now
SYSOPS      = ENV.fetch('BBS_SYSOPS', '').split(',').map { |name| name.strip.downcase }.reject(&:empty?)
account_service      = AccountService.new(AccountRepository.new(
                         ENV.fetch('ACCOUNTS_PATH', 'data/accounts.csv')), reserved: SYSOPS)
WIKI_SECTIONS = {
  platforms: { prefix: '/platforms', title: 'Platform Guides' },
  engines:   { prefix: '/engines',   title: 'Engines' },
  dos:       { prefix: '/dos',       title: 'DOS Corner' }
}.freeze
DESKTOP_ART = ENV.fetch('BBS_DESKTOP_ART', 'data/art/teletype.ansi')

BBS.configure do |config|
  config.mouse        = true
  config.idle_seconds = 600

  config.on_session_end = lambda do |session|
    online_service.remove(session.session_id)
    chat_service.unsubscribe(session.session_id)
    last_callers_service.finish(session.session_id)
  end

  config.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success
    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(value) { AccountService.normalize_name(value) }
    call do |ctx, runner|
      name = ctx[:username]
      ctx[:lang] = 'en'
      ctx[:authenticated] = false
      if account_service.registered?(name)
        3.times do
          runner.write "  \e[1;37mPassword\e[0m: "
          password = runner.readline(mask: '*')
          break if password.nil?
          if account_service.authenticate(name, password)
            ctx[:authenticated] = true
            break
          end
          runner.write "  \e[1;31mWrong password.\e[0m\r\n"
        end
        unless ctx[:authenticated]
          runner.write "\r\n  \e[1;31m#{name} is a registered name. Call again, or use another name.\e[0m\r\n\r\n"
          next :halt
        end
      end
      # A terminal that never reported its size is a scanner, not a caller:
      # it may look around, but it is not listed anywhere.
      if runner.session.naws_reported?
        online_service.add(ctx[:session_id], name)
        last_callers_service.start(name, ctx[:session_id])
      end
      chat_service.subscribe(ctx[:session_id])
      nil
    end
    app(BBS::Application.define do
      theme BBS::Theme.neumanntronics
      services online:       online_service,
               boards:       board_service,
               wiki:         wiki_service,
               games:        games_service,
               chat:         chat_service,
               last_callers: last_callers_service,
               profile:      profile_service,
               accounts:     account_service,
               site:         site_service,
               discord:      discord,
               uptime:       STARTED_AT

      helpers do
        def sysop?
          name = (context[:username] || '').downcase
          context[:authenticated] && SYSOPS.include?(name)
        end

        def open_new_post
          board = services[:boards].boards.first
          if board
            open_window(:compose_message, board: board)
          else
            BBS::Dialogs.message(self, 'Select a board first.', title: ' Compose ')
          end
        end
      end

      # ── Windows ────────────────────────────────────────────────────────────────

      window :bulletin, type: :info do |window_spec|
        window_spec.title  ' Welcome '
        window_spec.width  72
        window_spec.height 22
        window_spec.scroll true
        window_spec.body do |ctx|
          UI::Formatters::Bulletin.body(
            username:       ctx[:username] || 'Anonymous',
            registered:     ctx[:authenticated],
            online_count:   ctx[:online].count,
            total_messages: ctx[:boards].total_count,
            recent_callers: ctx[:last_callers].recent(3),
            releases:       ctx[:games].latest_releases(3),
            events:         ctx[:site].upcoming_events(2)
          )
        end
        window_spec.button label: '&Continue', primary: true, cancel: true
      end

      window :system_info, type: :info do |window_spec|
        window_spec.title  ' System Info '
        window_spec.width  60
        window_spec.height 14
        window_spec.body do |ctx|
          rows = [
            ['Online users', ctx[:online].count.to_s],
            ['Messages',     ctx[:boards].total_count.to_s],
            ['Boards',       ctx[:boards].boards.size.to_s],
            ['Wiki',         'https://wiki.teletypegames.org'],
            ['Games API',    'https://teletypegames.org'],
            ['Discord feed', ctx[:discord].enabled? ? 'on' : 'off'],
            ['Platform',     RUBY_PLATFORM],
            ['Ruby',         RUBY_VERSION],
            ['Uptime',       UI::Formatters::SystemInfo.format_uptime(ctx[:uptime])]
          ]
          [{ kv: rows, label_width: 15 }]
        end
      end

      window :messages, type: :master_detail do |window_spec|
        window_spec.title         ' Message Boards '
        window_spec.list_width    20
        window_spec.empty_message '  (no boards configured)'
        window_spec.items         { |ctx| ctx[:boards].boards }
        window_spec.item_label    { |board, _ctx| board.title }
        window_spec.render_detail do |board, width, ctx|
          UI::Formatters::Board.lines(ctx[:boards].messages(board.id, 100), board.title, width)
        end
        window_spec.action label: '&New', align: :left do |window, ctx|
          board = window.list_widget.selected_item
          ctx[:app].open_window(:compose_message, board: board,
                                on_posted: -> { window.reload_detail })
          :keep
        end
        window_spec.action label: '&Refresh', align: :left do |window, _ctx|
          window.reload_detail
          :keep
        end
      end

      window :compose_message, type: :form do |window_spec|
        window_spec.title        { |ctx| ctx[:board] ? " Post to #{ctx[:board].title} " : ' Compose ' }
        window_spec.width        { |ctx| [ctx[:app].cols - 8, 70].min }
        window_spec.height       14
        window_spec.hint         { |ctx| "From: #{ctx[:username] || 'Anonymous'} — Ctrl-Enter sends" }
        window_spec.submit_label '&Send'
        window_spec.cancel_label '&Cancel'
        window_spec.field :body, type: :textarea, max_length: 1000
        window_spec.on_submit do |values, form, ctx|
          if ctx[:board].nil?
            form.error('Select a board first.')
            :keep
          else
            username = ctx[:username] || 'Anonymous'
            case ctx[:boards].post(ctx[:board].id, username, values[:body])
            when :empty
              form.error('Message cannot be empty.')
              :keep
            else
              ctx[:discord].board_post(ctx[:board].title, username, values[:body])
              ctx[:on_posted]&.call
              :close
            end
          end
        end
      end

      window :wiki, type: :master_detail do |window_spec|
        window_spec.title         { |ctx| " #{WIKI_SECTIONS[ctx[:section]][:title]} " }
        window_spec.list_width    { |ctx| [32, ctx[:app].cols / 3].max }
        window_spec.empty_message '  (no pages found)'
        window_spec.close_button  false
        window_spec.items do |ctx|
          pages = ctx[:wiki].section(WIKI_SECTIONS[ctx[:section]][:prefix], lang: ctx[:lang])
          if ctx[:section] == :dos
            intro = WikiPageModel.new(title: 'FTP & DOSINST', description: UI::Formatters::Dos::FTP_INTRO)
            [intro, *pages]
          else
            pages
          end
        end
        window_spec.item_label do |page, ctx|
          depth = page.path ? page.path.count('/') - WIKI_SECTIONS[ctx[:section]][:prefix].count('/') : 0
          "#{'  ' * depth}#{page.title}"
        end
        window_spec.render_detail do |page, width, ctx|
          text = page.path ? ctx[:wiki].content(page.path, lang: ctx[:lang]) : page.description
          BBS::Markdown.to_lines(text, width: width - 1, theme: ctx[:app].theme)
        end
        window_spec.bottom_meta do |page, ctx|
          page.path ? ctx[:wiki].page_url(page.path, lang: ctx[:lang]) : 'ftp://ftp.teletypegames.org'
        end
      end

      window :games, type: :master_detail do |window_spec|
        window_spec.title         { |ctx| ctx[:platform] ? " Game Catalog — #{ctx[:platform]} " : ' Game Catalog ' }
        window_spec.list_width    34
        window_spec.empty_message '  (no games)'
        window_spec.items         { |ctx| ctx[:games].by_platform(ctx[:platform]) }
        window_spec.item_label    { |game, _ctx| UI::Formatters::Game.label(game) }
        window_spec.render_detail do |game, width, ctx|
          UI::Formatters::Game.card(game, width, catalog_url: ctx[:games].catalog_url(game))
        end
        window_spec.action label: '&Platform', align: :left do |_window, ctx|
          cycle = [nil, *ctx[:games].platforms]
          following = cycle[(cycle.index(ctx[:platform]) || 0) + 1]
          ctx[:app].open_window(:games, platform: following)
          :close
        end
      end

      window :news, type: :info do |window_spec|
        window_spec.title  ' News '
        window_spec.width  { |ctx| [ctx[:app].cols - 6, 76].min }
        window_spec.height { |ctx| [ctx[:app].rows - 4, 24].min }
        window_spec.scroll true
        window_spec.body do |ctx|
          UI::Formatters::News.body(
            releases:    ctx[:games].latest_releases(5),
            events:      ctx[:site].upcoming_events(5),
            posts:       ctx[:wiki].list('blog', lang: ctx[:lang]),
            catalog_url: ->(game) { ctx[:games].catalog_url(game) },
            post_url:    ->(post) { "https://teletypegames.org/blog/#{post.path.delete_prefix('blog/')}" }
          )
        end
      end

      window :team, type: :info do |window_spec|
        window_spec.title  ' The Team '
        window_spec.width  64
        window_spec.height { |ctx| [ctx[:app].rows - 4, 22].min }
        window_spec.scroll true
        window_spec.body   { |ctx| UI::Formatters::Team.body(ctx[:site].members) }
      end

      window :network, type: :info do |window_spec|
        window_spec.title  ' BBS Network '
        window_spec.width  72
        window_spec.height 16
        window_spec.body   { |_ctx| UI::Formatters::Network.body }
      end

      window :register, type: :form do |window_spec|
        window_spec.title        { |ctx| " Register — #{ctx[:username]} " }
        window_spec.width        60
        window_spec.height       11
        window_spec.hint         'Next time the BBS asks for this password.'
        window_spec.submit_label '&Register'
        window_spec.cancel_label '&Cancel'
        window_spec.field :password, label: 'Password', password: true
        window_spec.field :confirm,  label: 'Again',    password: true
        window_spec.on_submit do |values, form, ctx|
          case ctx[:accounts].register(ctx[:username], values[:password], values[:confirm])
          when :ok
            ctx[:app].context[:authenticated] = true
            BBS::Dialogs.message(ctx[:app], "#{ctx[:username]} is yours now.", title: ' Registered ')
            :close
          when :anonymous then form.error('Log in with a name first, not as Anonymous.'); :keep
          when :reserved  then form.error('This name is reserved for the sysop.'); :keep
          when :taken     then form.error('This name is already registered.'); :keep
          when :too_short then form.error("At least #{AccountService::MIN_PASSWORD} characters."); :keep
          when :mismatch  then form.error('The two passwords differ.'); :keep
          end
        end
      end

      window :online_users, type: :info do |window_spec|
        window_spec.title  ' Online Users '
        window_spec.width  50
        window_spec.scroll true
        window_spec.height { |ctx| [ctx[:online].user_list.size + 6, 10].max }
        window_spec.body   { |ctx| UI::Formatters::Users.online_list(ctx[:online].user_list, ctx[:username]) }
      end

      window :last_callers, type: :info do |window_spec|
        window_spec.title  ' Last Callers '
        window_spec.width  64
        window_spec.scroll true
        window_spec.height { |ctx| [ctx[:last_callers].recent(15).size + 6, 10].max }
        window_spec.body   { |ctx| UI::Formatters::Users.last_callers_list(ctx[:last_callers].recent(15)) }
      end

      window :chat, type: :stream do |window_spec|
        window_spec.title       ' Live Chat '
        window_spec.placeholder 'Type a message and press Enter…'
        window_spec.initial_lines do |ctx|
          ctx[:chat].history.map { |line| UI::Formatters::Chat.line(line) }
        end
        window_spec.on_submit do |text, _app, ctx|
          ctx[:chat].broadcast(ctx[:username] || 'Anonymous', text.strip)
        end
        window_spec.on_poll do |app_, ctx|
          ctx[:chat].drain(app_.session_id).map { |line| UI::Formatters::Chat.line(line) }
        end
      end

      window :profile, type: :form do |window_spec|
        window_spec.title  { |ctx| " Profile — #{ctx[:username] || 'Anonymous'} " }
        window_spec.width  64
        window_spec.height 14
        window_spec.prefill do |ctx|
          existing = ctx[:profile].find(ctx[:username] || 'Anonymous') || {}
          {
            signature: existing['signature'].to_s,
            location:  existing['location'].to_s,
            homepage:  existing['homepage'].to_s,
            notes:     existing['notes'].to_s
          }
        end
        window_spec.field :signature, label: 'Signature'
        window_spec.field :location,  label: 'Location'
        window_spec.field :homepage,  label: 'Homepage'
        window_spec.field :notes,     label: 'Notes'
        window_spec.on_submit do |values, _form, ctx|
          ctx[:profile].update(ctx[:username], **values)
          BBS::Dialogs.message(ctx[:app], 'Profile saved.', title: ' Saved ')
          :close
        end
      end

      window :sysop_console, type: :info do |window_spec|
        window_spec.title  ' Sysop Console '
        window_spec.width  70
        window_spec.height 18
        window_spec.scroll true
        window_spec.body do |ctx|
          UI::Formatters::Sysop.console_body(
            username:         ctx[:username],
            online_count:     ctx[:online].count,
            total_messages:   ctx[:boards].total_count,
            chat_subscribers: ctx[:chat].subscriber_count,
            online_users:     ctx[:online].user_list,
            recent_callers:   ctx[:last_callers].recent(5)
          )
        end
        window_spec.button label: '&Broadcast', align: :left do |_window, ctx|
          BBS::Dialogs.input(ctx[:app], prompt: 'Sysop broadcast message:',
                             title: ' Broadcast ', width: 64,
                             on_submit: lambda do |text|
                               next if text.strip.empty?
                               ctx[:chat].broadcast("[SYSOP] #{ctx[:username]}", text.strip)
                               ctx[:discord].broadcast(ctx[:username], text.strip)
                             end)
          :keep
        end
        window_spec.button label: '&Close', cancel: true
      end

      # ── Menubar ────────────────────────────────────────────────────────────────

      menubar do
        menu '&File' do
          item '&Bulletin'    do open_window(:bulletin) end
          item '&News'        do open_window(:news) end
          item '&System Info' do open_window(:system_info) end
          separator
          item 'E&xit', shortcut: 'Alt-X' do :halt end
        end

        menu '&Messages' do
          item '&Boards…',   shortcut: 'F2' do open_window(:messages) end
          item '&New Post…', shortcut: 'F3' do open_new_post end
        end

        menu 'F&iles' do
          item '&Game Catalog'    do open_window(:games) end
          item '&Platform Guides' do open_window(:wiki, section: :platforms) end
          item '&Engines'         do open_window(:wiki, section: :engines) end
          item '&DOS Corner'      do open_window(:wiki, section: :dos) end
        end

        menu '&Users' do
          item '&Online'       do open_window(:online_users) end
          item '&Last Callers' do open_window(:last_callers) end
          item '&Team'         do open_window(:team) end
          separator
          item '&Profile…' do
            if context[:authenticated]
              open_window(:profile)
            else
              BBS::Dialogs.message(self, 'Register your name first (Users > Register…): ' \
                                         'a profile belongs to a registered name.', title: ' Profile ', width: 60)
            end
          end
          item '&Register…' do
            if context[:authenticated]
              BBS::Dialogs.message(self, "#{context[:username]} is already registered and logged in.", title: ' Register ')
            elsif context[:username] == AccountService::ANONYMOUS
              BBS::Dialogs.message(self, 'Call again with a name to register it.', title: ' Register ')
            else
              open_window(:register)
            end
          end
          item 'Lan&guage EN/HU' do
            context[:lang] = context[:lang] == 'hu' ? 'en' : 'hu'
            BBS::Dialogs.message(self, context[:lang] == 'hu' ? 'Wiki pages now in Hungarian.' : 'Wiki pages now in English.',
                                 title: ' Language ')
          end
        end

        menu '&Chat' do
          item '&Open chat', shortcut: 'F4' do open_window(:chat) end
        end

        menu 'Net&work' do
          item '&Other systems' do open_window(:network) end
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
              'Teletype BBS — the telnet board of Teletype Games, powered by rubbs. ' \
              'News, our game catalog, the wiki guides and a live chat. ' \
              'Register your name under Users to keep it. Other systems: Network menu.',
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

      status_hint('F1',  'Help')   { BBS::Dialogs.message(self, 'Top menu: Alt+letter — Windows: Tab/Shift-Tab — Close: Esc') }
      status_hint('F2',  'Boards') { open_window(:messages) }
      status_hint('F3',  'Post')   { open_new_post }
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
    end)
    say 'Goodbye!', style: :muted
  end
end

BBS.start
