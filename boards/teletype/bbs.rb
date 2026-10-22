# frozen_string_literal: true

require 'bbs'
require 'sermo'
require 'impostor'
require 'time'

require_relative 'lib/domain/repository/online_users_repository'
require_relative 'lib/domain/repository/board_repository'
require_relative 'lib/domain/repository/wiki_repository'
require_relative 'lib/domain/repository/catalog_repository'
require_relative 'lib/domain/repository/last_callers_repository'
require_relative 'lib/domain/repository/profile_repository'
require_relative 'lib/domain/repository/account_repository'
require_relative 'lib/domain/repository/site_repository'
require_relative 'lib/domain/repository/oneliner_repository'
require_relative 'lib/domain/repository/ftp_repository'
require_relative 'lib/domain/repository/gitea_repository'
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
require_relative 'lib/domain/service/oneliner_service'
require_relative 'lib/domain/service/file_library_service'
require_relative 'lib/domain/service/dev_log_service'
require_relative 'lib/domain/service/art_service'
require_relative 'lib/domain/repository/mail_repository'
require_relative 'lib/domain/repository/last_read_repository'
require_relative 'lib/domain/repository/vote_repository'
require_relative 'lib/domain/service/mail_service'
require_relative 'lib/domain/service/voting_service'
require_relative 'lib/domain/service/file_area_service'
require_relative 'lib/doors/commodore'
require_relative 'lib/doors/ra'
require_relative 'lib/doors/trivia'
require_relative 'lib/characters/master'
require_relative 'lib/bbs/ui/formatters'
require_relative 'lib/bbs/ui/classic_formatters'

online_service       = OnlineService.new(OnlineUsersRepository.new)
board_service        = BoardService.new(BoardRepository.new(
                         ENV.fetch('BOARDS_PATH', 'data/boards'),
                         legacy_path: ENV.fetch('MESSAGES_PATH', 'data/messages.dat')),
                         last_read: LastReadRepository.new(ENV.fetch('LAST_READ_PATH', 'data/last_read.csv')))
wiki_service         = WikiService.new(WikiRepository.new)
games_service        = GamesService.new(CatalogRepository.new)
chat_service         = ChatService.new
last_callers_service = LastCallersService.new(LastCallersRepository.new(
                         ENV.fetch('LAST_CALLERS_PATH', 'data/last_callers.csv')))
profile_service      = ProfileService.new(ProfileRepository.new(
                         ENV.fetch('PROFILE_PATH', 'data/profiles.csv')))
site_service         = SiteService.new(SiteRepository.new)
discord              = DiscordNotifier.new(ENV['BBS_DISCORD_WEBHOOK'])
oneliner_service     = OnelinerService.new(OnelinerRepository.new(
                         ENV.fetch('ONELINERS_PATH', 'data/oneliners.csv')))
file_library         = FileLibraryService.new(FtpRepository.new(ENV.fetch('BBS_FTP_HOST', 'ftp.teletypegames.org')))
dev_log_service      = DevLogService.new(GiteaRepository.new)
ttg_master           = TtgMaster.new(games: games_service, site: site_service)
impostor_sessions    = Impostor.sessions_store(ENV.fetch('IMPOSTOR_SESSIONS_PATH', 'data/impostor_sessions.csv'))

STARTED_AT  = Time.now
SYSOPS      = ENV.fetch('BBS_SYSOPS', '').split(',').map { |name| name.strip.downcase }.reject(&:empty?)
account_service = AccountService.new(AccountRepository.new(
                         ENV.fetch('ACCOUNTS_PATH', 'data/accounts.csv')), reserved: SYSOPS)
mail_service    = MailService.new(MailRepository.new(ENV.fetch('MAIL_PATH', 'data/mail.csv')),
                                  accounts: account_service, sysops: SYSOPS)
DOOR_NAMES      = ['SERMO', 'Commodore 64', 'Commodore Plus/4', 'Impostor', 'Chat of Ra', 'TTG Trivia'].freeze
voting_service  = VotingService.new(VoteRepository.new(ENV.fetch('VOTES_PATH', 'data/votes.csv')),
                                    path: File.expand_path('lib/content/polls.yml', __dir__),
                                    games: games_service, doors: DOOR_NAMES)
file_areas      = FileAreaService.new(games: games_service, files: file_library)
trivia_scores   = Trivia::Scores.new(ENV.fetch('TRIVIA_SCORES_PATH', 'data/trivia_scores.csv'))
BULLETINS_DIR   = File.expand_path('lib/content/bulletins', __dir__)
LOGON_ART       = ENV.fetch('BBS_LOGON_ART', File.expand_path('lib/content/logon.ans', __dir__))
WIKI_SECTIONS = {
  platforms: { prefix: '/platforms', title: 'Platform Guides' },
  engines:   { prefix: '/engines',   title: 'Engines' },
  dos:       { prefix: '/dos',       title: 'DOS Corner' }
}.freeze
DESKTOP_ART = ENV.fetch('BBS_DESKTOP_ART', 'data/art/teletype.ansi')
art_service = ArtService.new(DESKTOP_ART, profile: profile_service)

BBS.configure do |config|
  config.mouse        = true
  config.idle_seconds = 600

  config.on_session_end = lambda do |session|
    online_service.remove(session.session_id)
    chat_service.unsubscribe(session.session_id)
    last_callers_service.finish(session.session_id)
  end

  config.flow = BBS::Flow.define do
    # The old way in: the modem, the board's art, then the name.
    call do |ctx, runner|
      UI::Formatters::Logon.connect(runner)
      art = File.exist?(LOGON_ART) ? BBS::Widgets::AnsiArt.load_file(LOGON_ART) : BBS::Widgets::AnsiArt.default_lines
      UI::Formatters::Logon.matrix(runner, art, caller_number: last_callers_service.caller_number,
                                                nodes: online_service.count)
      ctx[:call_started] = Time.now
      nil
    end
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
          sleep 2
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
    rescue StandardError => e
      warn "Login error: #{e.class}: #{e.message}"
      :halt
    end
    # The logon sequence: who is calling, then the scans of the old boards.
    call do |ctx, runner|
      name       = ctx[:username]
      registered = ctx[:authenticated]
      sysop      = registered && SYSOPS.include?(name.downcase)
      ctx[:caller_number] = last_callers_service.caller_number
      fresh     = Time.now - (FileAreaService::NEW_DAYS * 86_400)
      new_files = games_service.latest_releases(5).select { |g| g.released_at > fresh }.map { |g| "#{g.title} #{g.version}" }
      polls_open = name == AccountService::ANONYMOUS ? 0 : voting_service.polls.count { |p| voting_service.ballot(p, name).nil? }
      UI::Formatters::Logon.screen(
        runner,
        name:          name,
        node:          online_service.node(ctx[:session_id])&.number,
        caller_number: ctx[:caller_number],
        stats:         last_callers_service.user_stats(name),
        registered:    registered,
        mail:          registered ? mail_service.unread_count(name, sysop: sysop) : nil,
        new_scan:      registered ? board_service.new_scan(name) : nil,
        polls_open:    polls_open,
        new_files:     new_files,
        quote:         UI::Formatters::Taglines.of_the_day(site_service.members)
      )
      runner.session.readkey(timeout: 120)
      nil
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      :halt
    rescue StandardError => e
      warn "Logon screen error: #{e.class}: #{e.message}"
      nil
    end
    teletype_app = BBS::Application.define do
      theme BBS::Theme.neumanntronics
      # Doors: full-line programs a caller can step into from the Doors menu.
      # The BBS hands the telnet line over and takes it back when the program exits.
      door :sermo,    Sermo::OS, label: '&SERMO'
      door :c64,      Commodore.os(Commodore::C64, games: games_service, files: file_library),
           label: '&Commodore 64'
      door :plus4,    Commodore.os(Commodore::PLUS4, games: games_service, files: file_library),
           label: 'Commodore &Plus/4'
      door :impostor, Impostor.flow(sessions: impostor_sessions), label: '&Impostor'
      door :ra,       Ra.os(games: games_service), label: 'Chat of &Ra'
      door :trivia,   Trivia.door(games: games_service, site: site_service, scores: trivia_scores),
           label: '&TTG Trivia'
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
               oneliners:    oneliner_service,
               files:        file_library,
               dev_log:      dev_log_service,
               art:          art_service,
               master:       ttg_master,
               mail:         mail_service,
               voting:       voting_service,
               file_areas:   file_areas,
               trivia:       trivia_scores,
               uptime:       STARTED_AT

      helpers do
        def sysop?
          name = (context[:username] || '').downcase
          context[:authenticated] && SYSOPS.include?(name)
        end

        def registered? = context[:authenticated] == true

        # Node, clock and time on line, the way the old status lines had them.
        def status_text
          node = services[:online].node(session_id)
          on   = UI::Formatters.duration(Time.now - (context[:call_started] || Time.now))
          "#{"Node #{node.number} │ " if node}#{Time.now.strftime('%H:%M')} │ #{on}"
        end

        # Mail that arrives during a call rings once, the way it used to.
        def check_mail
          return unless registered?

          unread = services[:mail].unread_count(context[:username], sysop: sysop?)
          known  = context[:mail_seen] || unread
          context[:mail_seen] = unread
          return unless unread > known

          session.write("\a")
          BBS::Dialogs.message(self, "New mail! You have #{unread} unread letter#{'s' if unread != 1}: Messages > Mail.",
                               title: ' Mail ')
        end

        def open_mail
          if registered? || sysop?
            open_window(:mail)
          else
            BBS::Dialogs.message(self, 'Mail belongs to registered names (Users > Register…). ' \
                                       'Anyone with a name can leave feedback for the sysop: Messages > Feedback.',
                                 title: ' Mail ', width: 60)
          end
        end

        def write_mail(to: '', subject: '', on_sent: nil)
          if context[:username] == AccountService::ANONYMOUS
            BBS::Dialogs.message(self, 'Call again with a name to write letters.', title: ' Mail ')
          else
            open_window(:compose_mail, to: to, subject: subject, on_sent: on_sent)
          end
        end

        def page_sysop
          name = context[:username] || 'Anonymous'
          if context[:paged]
            return BBS::Dialogs.message(self, 'The bell has rung already this call. Leave a letter instead.',
                                        title: ' Page ')
          end

          context[:paged] = true
          session.write("\a")
          online = services[:online].nodes.any? { |n| SYSOPS.include?(n.name.downcase) }
          services[:chat].broadcast('[PAGE]', "#{name} is paging the sysop!")
          services[:discord].page(name)
          if online
            BBS::Dialogs.message(self, UI::Formatters::PageSysop.text(true), title: ' Paging the Sysop… ', width: 60)
          else
            BBS::Dialogs.confirm(self, UI::Formatters::PageSysop.text(false), title: ' Paging the Sysop… ',
                                       on_yes: -> { write_mail(to: MailService::SYSOP, subject: 'Page') })
          end
        end

        def vote_on(poll, window = nil)
          return unless poll

          name = context[:username] || 'Anonymous'
          if name == AccountService::ANONYMOUS
            return BBS::Dialogs.message(self, 'Call again with a name to vote.', title: ' Voting Booth ')
          end

          BBS::Dialogs.input(self, prompt: "The number of your choice, 1 to #{poll.options.size}:",
                                   title: ' Your vote ', width: 56,
                                   on_submit: lambda do |text|
                                     option = poll.options[text.to_i - 1] if text.to_i.positive?
                                     if option && services[:voting].vote(poll, name, option) == :ok
                                       window&.reload_detail
                                       BBS::Dialogs.message(self, "Your vote: #{option}.", title: ' Voting Booth ')
                                     else
                                       BBS::Dialogs.message(self, "Type a number from 1 to #{poll.options.size}.",
                                                            title: ' Voting Booth ')
                                     end
                                   end)
        end

        def open_new_post
          board = services[:boards].boards.first
          if board
            open_window(:compose_message, board: board)
          else
            BBS::Dialogs.message(self, 'Select a board first.', title: ' Compose ')
          end
        end

        # The TTG Master answers in a thread of his own and the window picks the
        # reply up on its next tick, so the board never waits for the model.
        def ask_master(ctx, question)
          queue = ctx[:master_queue]
          UI::Formatters::Master.lines('You', question, cols, you: true).each { |line| queue << line }
          if ctx[:master_busy]
            UI::Formatters::Master.lines('TTG Master', 'One question at a time, caller.', cols).each { |line| queue << line }
            return
          end

          ctx[:master_busy] = true
          width = cols
          Thread.new do
            reply = ctx[:master].answer(question, ctx)
            UI::Formatters::Master.lines('TTG Master', reply, width).each { |line| queue << line }
          rescue StandardError => e
            warn "TTG Master: #{e.class}: #{e.message}"
          ensure
            ctx[:master_busy] = false
          end
        end

        def ftp_open(window, ctx, path)
          entries = services[:files].list(path)
          if entries
            ctx[:ftp_path] = context[:ftp_path] = path
            window.replace_items(UI::Formatters::Ftp.items(path, entries),
                                 title: UI::Formatters::Ftp.title(services[:files].host, path))
          else
            BBS::Dialogs.message(self, "The FTP server did not answer for #{path}. Try again later.", title: ' FTP ')
          end
        end

        def ftp_download(entry)
          files = services[:files]
          unless files.downloadable?(entry)
            return BBS::Dialogs.message(self, UI::Formatters::Ftp.too_big(entry, files), title: ' Download ', width: 70)
          end

          BBS::Dialogs.confirm(self, UI::Formatters::Ftp.offer(entry), title: ' Download ',
                                     on_yes: -> { ftp_send(entry) })
        end

        def ftp_send(entry)
          result = with_line do |session|
            session.write(UI::Formatters::Ftp.fetching(entry))
            data = services[:files].download(entry)
            next :unreadable unless data

            session.write(UI::Formatters::Ftp.sending(entry))
            BBS::Zmodem.send_files(session, [[entry.name, data, entry.modified]])
          end
          BBS::Dialogs.message(self, UI::Formatters::Ftp.result(result, entry, services[:files]),
                               title: ' Download ', width: 64)
        end

        def view_art(name)
          lines = services[:art].lines(name)
          title = services[:art].sauce(name)&.title.to_s
          with_line do |session|
            BBS::Widgets::AnsiArt.view(session, lines, title: title.empty? ? name : "#{name} — #{title}")
          end
        end

        def show_art(name)
          lines = services[:art].lines(name)
          @desktop_art.lines      = lines
          @desktop_art.art_height = lines.size
          context[:desktop_art]   = name
        end
      end

      # ── Windows ────────────────────────────────────────────────────────────────

      window :bulletin, type: :info do |window_spec|
        window_spec.maximizable true
        window_spec.title  ' Welcome '
        window_spec.width  72
        window_spec.height 23
        window_spec.scroll true
        window_spec.body do |ctx|
          UI::Formatters::Bulletin.body(
            username:       ctx[:username] || 'Anonymous',
            registered:     ctx[:authenticated],
            online_count:   ctx[:online].count,
            total_messages: ctx[:boards].total_count,
            recent_callers: ctx[:last_callers].recent(3),
            releases:       ctx[:games].latest_releases(3),
            events:         ctx[:site].upcoming_events(2),
            oneliners:      ctx[:oneliners].recent(5)
          )
        end
        window_spec.button label: 'Ask the TTG &Master', align: :left do |_window, ctx|
          ctx[:app].open_window(:master)
        end
        window_spec.button label: '&Continue', primary: true, cancel: true
      end

      window :system_info, type: :info do |window_spec|
        window_spec.title  ' System Info '
        window_spec.width  60
        window_spec.height 15
        window_spec.body do |ctx|
          rows = [
            ['Nodes in use', ctx[:online].count.to_s],
            ['Calls',        "#{ctx[:last_callers].total_calls} (#{ctx[:last_callers].calls_today} today)"],
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
        window_spec.maximizable true
        window_spec.title         ' Message Boards '
        window_spec.list_width    20
        window_spec.empty_message '  (no boards configured)'
        window_spec.items         { |ctx| ctx[:boards].boards }
        window_spec.item_label do |board, ctx|
          unread = ctx[:authenticated] ? ctx[:boards].unread(ctx[:username], board.id) : 0
          unread.positive? ? "#{board.title} (#{unread})" : board.title
        end
        window_spec.render_detail do |board, width, ctx|
          ctx[:boards].mark_read(ctx[:username], board.id) if ctx[:authenticated]
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
        window_spec.maximizable true
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
            case ctx[:boards].post(ctx[:board].id, username, values[:body], session_id: ctx[:session_id])
            when :empty
              form.error('Message cannot be empty.')
              :keep
            when :too_fast
              form.error("One post every #{BoardService::COOLDOWN} seconds, please.")
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
        window_spec.maximizable true
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
        window_spec.maximizable true
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
        window_spec.maximizable true
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
        window_spec.maximizable true
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
        window_spec.title  ' Who is Online '
        window_spec.width  74
        window_spec.scroll true
        window_spec.height { |ctx| [ctx[:online].count + 8, 10].max }
        window_spec.body   { |ctx| UI::Formatters::Nodes.body(ctx[:online].nodes, ctx[:app].session_id) }
      end

      window :last_callers, type: :info do |window_spec|
        window_spec.title  ' Last Callers '
        window_spec.width  64
        window_spec.scroll true
        window_spec.height { |ctx| [ctx[:last_callers].recent(15).size + 6, 10].max }
        window_spec.body   { |ctx| UI::Formatters::Users.last_callers_list(ctx[:last_callers].recent(15)) }
      end

      window :chat, type: :stream do |window_spec|
        window_spec.maximizable true
        window_spec.title       ' Live Chat '
        window_spec.placeholder 'Type a message and press Enter…'
        window_spec.initial_lines do |ctx|
          ctx[:chat].drain(ctx[:session_id])
          ctx[:chat].history.map { |line| UI::Formatters::Chat.line(line) }
        end
        window_spec.on_submit do |text, _app, ctx|
          ctx[:chat].broadcast(ctx[:username] || 'Anonymous', text.strip) if ctx[:chat].may_speak?(ctx[:session_id])
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

      window :oneliners, type: :info do |window_spec|
        window_spec.maximizable true
        window_spec.title  ' Oneliners '
        window_spec.width  { |ctx| [ctx[:app].cols - 6, 78].min }
        window_spec.height { |ctx| [ctx[:oneliners].recent(30).size + 6, 10].max }
        window_spec.scroll true
        window_spec.body   { |ctx| UI::Formatters::Oneliners.body(ctx[:oneliners].recent(30)) }
        window_spec.button label: '&Write', align: :left do |window, ctx|
          app = ctx[:app]
          BBS::Dialogs.input(app, prompt: "Your line on the wall (#{OnelinerService::MAX_LENGTH} characters at most):",
                                  title: ' Oneliner ', width: 74,
                                  on_submit: lambda do |text|
                                    case ctx[:oneliners].add(app.context[:username], text)
                                    when :ok
                                      app.close_window(window)
                                      app.open_window(:oneliners)
                                    when :anonymous
                                      BBS::Dialogs.message(app, 'Call again with a name to write on the wall.',
                                                           title: ' Oneliners ')
                                    when :too_long
                                      BBS::Dialogs.message(app, "At most #{OnelinerService::MAX_LENGTH} characters.",
                                                           title: ' Oneliners ')
                                    end
                                  end)
          :keep
        end
        window_spec.button label: '&Close', cancel: true
      end

      # A plain FTP client: Enter opens a folder (or sends a file), .. goes up.
      window :ftp, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title do |ctx|
          ctx[:ftp_path] ||= ctx[:app].context[:ftp_path] || FileLibraryService::ROOT
          UI::Formatters::Ftp.title(ctx[:files].host, ctx[:ftp_path])
        end
        window_spec.list_width    { |ctx| [40, (ctx[:app].cols / 2) - 4].min }
        window_spec.empty_message '  (the FTP server did not answer — try again later)'
        window_spec.close_button  false
        window_spec.items do |ctx|
          UI::Formatters::Ftp.items(ctx[:ftp_path], ctx[:files].list(ctx[:ftp_path]))
        end
        window_spec.item_label    { |entry, _ctx| UI::Formatters::Ftp.label(entry) }
        window_spec.render_detail do |entry, width, ctx|
          UI::Formatters::Ftp.detail(entry, width, files: ctx[:files], theme: ctx[:app].theme)
        end
        window_spec.bottom_meta do |entry, ctx|
          entry.dir ? 'Enter: open the folder' : UI::Formatters::Ftp.meta(entry, ctx[:files])
        end
        window_spec.on_activate do |entry, window, ctx|
          if entry.dir
            ctx[:app].ftp_open(window, ctx, entry.path)
          else
            ctx[:app].ftp_download(entry)
          end
        end
        window_spec.action label: '&Up', align: :left do |window, ctx|
          ctx[:app].ftp_open(window, ctx, ctx[:files].parent(ctx[:ftp_path]))
          :keep
        end
        window_spec.action label: '&Download', align: :left do |window, ctx|
          entry = window.list_widget.selected_item
          ctx[:app].ftp_download(entry) if entry && !entry.dir
          :keep
        end
        window_spec.action label: '&Close', cancel: true
      end

      window :dev_log, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' Dev Log — git.teletypegames.org '
        window_spec.list_width    36
        window_spec.empty_message '  (no activity, or Gitea did not answer)'
        window_spec.items         { |ctx| ctx[:dev_log].recent(60) }
        window_spec.item_label    { |activity, _ctx| UI::Formatters::DevLog.label(activity) }
        window_spec.render_detail do |activity, width, ctx|
          UI::Formatters::DevLog.detail(activity, width,
                                        commit_url:  ->(sha) { ctx[:dev_log].commit_url(activity, sha) },
                                        release_url: ctx[:dev_log].release_url(activity),
                                        repo_url:    ctx[:dev_log].repo_url(activity))
        end
        window_spec.bottom_meta { |_activity, _ctx| '· push   ◆ tag   ★ release   + repository' }
      end

      window :gallery, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' ANSI Gallery '
        window_spec.list_width    24
        window_spec.empty_message '  (no art files)'
        window_spec.items         { |ctx| ctx[:art].files }
        window_spec.item_label do |name, ctx|
          name == ctx[:app].context[:desktop_art] ? "#{name} ◄" : name
        end
        window_spec.render_detail do |name, width, ctx|
          UI::Formatters::Gallery.detail(name, ctx[:art].sauce(name), ctx[:art].size(name), ctx[:art].lines(name), width)
        end
        window_spec.bottom_meta do |_name, _ctx|
          'Enter/View: full screen · Desktop: for this call · Favourite: for every call'
        end
        window_spec.on_activate { |name, _window, ctx| ctx[:app].view_art(name) }
        window_spec.action label: '&View', align: :left do |window, ctx|
          name = window.list_widget.selected_item
          ctx[:app].view_art(name) if name
          :keep
        end
        window_spec.action label: '&Desktop', align: :left do |window, ctx|
          name = window.list_widget.selected_item
          ctx[:app].show_art(name) if name
          :close
        end
        window_spec.action label: '&Favourite', align: :left do |window, ctx|
          app  = ctx[:app]
          name = window.list_widget.selected_item
          if name.nil?
            nil
          elsif app.context[:authenticated]
            ctx[:art].set_favourite(app.context[:username], name)
            app.show_art(name)
            BBS::Dialogs.message(app, "#{name} is your desktop from now on.", title: ' Favourite ')
          else
            BBS::Dialogs.message(app, 'Register your name first (Users > Register…): ' \
                                      'a favourite belongs to a registered name.', title: ' Favourite ', width: 60)
          end
          :keep
        end
      end

      window :master, type: :stream do |window_spec|
        window_spec.maximizable true
        window_spec.title       ' Ask the TTG Master '
        window_spec.placeholder 'Ask about the board and press Enter…'
        window_spec.initial_lines do |ctx|
          ctx[:master_queue] = Queue.new
          ctx[:app].ask_master(ctx, ctx[:question]) if ctx[:question]
          UI::Formatters::Master.lines('TTG Master', 'Hey, caller! I am the sysop of this board. Ask me where ' \
                                                     'things are, what is new, what is coming up.', ctx[:app].cols)
        end
        window_spec.on_submit do |text, app_, ctx|
          app_.ask_master(ctx, text.strip)
        end
        window_spec.on_poll do |_app, ctx|
          lines = []
          lines << ctx[:master_queue].pop until ctx[:master_queue].empty?
          lines
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

      window :user_list, type: :info do |window_spec|
        window_spec.maximizable true
        window_spec.title  ' User Listing '
        window_spec.width  74
        window_spec.scroll true
        window_spec.height { |ctx| (ctx[:accounts].names.size + 9).clamp(10, [ctx[:app].rows - 4, 10].max) }
        window_spec.body do |ctx|
          rows = ctx[:accounts].names.map do |name|
            [name, ctx[:last_callers].user_stats(name), ctx[:profile].find(name)&.fetch('location', nil),
             ctx[:online].online?(name)]
          end
          UI::Formatters::UserList.body(rows.sort_by { |_, st, _, _| -(st&.calls || 0) })
        end
      end

      window :my_stats, type: :info do |window_spec|
        window_spec.title  { |ctx| " Your Stats — #{ctx[:username]} " }
        window_spec.width  60
        window_spec.height 16
        window_spec.body do |ctx|
          name = ctx[:username] || 'Anonymous'
          UI::Formatters::MyStats.body(
            name:          name,
            registered:    ctx[:authenticated],
            stats:         ctx[:last_callers].user_stats(name),
            node:          ctx[:online].node(ctx[:app].session_id),
            caller_number: ctx[:caller_number] || ctx[:last_callers].caller_number,
            posts:         ctx[:boards].top_posters(1000).find { |n, _| n.casecmp?(name) }&.last || 0,
            ballots:       ctx[:voting].polls.count { |p| ctx[:voting].ballot(p, name) },
            letters:       ctx[:authenticated] ? ctx[:mail].inbox(name, sysop: ctx[:app].sysop?).size : nil,
            member_since:  ctx[:accounts].created_at(name)
          )
        end
      end

      window :hall_of_fame, type: :info do |window_spec|
        window_spec.maximizable true
        window_spec.title  ' Hall of Fame '
        window_spec.width  { |ctx| [ctx[:app].cols - 6, 76].min }
        window_spec.height { |ctx| [ctx[:app].rows - 4, 24].min }
        window_spec.scroll true
        window_spec.body do |ctx|
          UI::Formatters::HallOfFame.body(
            downloads: ctx[:games].top_downloads(8).map { |g| [g.title, g.downloads] },
            callers:   ctx[:last_callers].top_callers(8),
            posters:   ctx[:boards].top_posters(8),
            trivia:    ctx[:trivia].best(8).map { |sc| [sc.username, sc.points.to_i] },
            width:     [ctx[:app].cols - 6, 76].min - 8
          )
        end
      end

      window :mail, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         { |ctx| " Mail — #{ctx[:username]} " }
        window_spec.list_width    36
        window_spec.empty_message { |ctx| UI::Formatters::Mail.empty(ctx[:authenticated]) }
        window_spec.items         { |ctx| ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?) }
        window_spec.item_label    { |letter, _ctx| UI::Formatters::Mail.label(letter) }
        window_spec.render_detail do |letter, width, ctx|
          ctx[:mail].mark_read(letter)
          UI::Formatters::Mail.detail(letter, width)
        end
        window_spec.bottom_meta { |_letter, _ctx| '• unread   Write · Reply · Delete' }
        window_spec.action label: '&Write', align: :left do |window, ctx|
          ctx[:app].write_mail(on_sent: -> { window.replace_items(ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?)) })
          :keep
        end
        window_spec.action label: '&Reply', align: :left do |window, ctx|
          letter = window.list_widget.selected_item
          if letter
            subject = letter.subject.start_with?('Re: ') ? letter.subject : "Re: #{letter.subject}"
            ctx[:app].write_mail(to: letter.from, subject: subject[0, MailService::SUBJECT_MAX])
          end
          :keep
        end
        window_spec.action label: '&Delete', align: :left do |window, ctx|
          letter = window.list_widget.selected_item
          if letter
            BBS::Dialogs.confirm(ctx[:app], "Delete the letter from #{letter.from}, \"#{letter.subject}\"?",
                                 title: ' Delete ',
                                 on_yes: lambda {
                                   ctx[:mail].delete(letter)
                                   window.replace_items(ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?))
                                 })
          end
          :keep
        end
      end

      window :compose_mail, type: :form do |window_spec|
        window_spec.maximizable true
        window_spec.title        ' Write a Letter '
        window_spec.width        { |ctx| [ctx[:app].cols - 8, 70].min }
        window_spec.height       18
        window_spec.hint         { |ctx| "From: #{ctx[:username]} — to a registered name, or Sysop. Ctrl-Enter sends" }
        window_spec.submit_label '&Send'
        window_spec.cancel_label '&Cancel'
        window_spec.prefill      { |ctx| { to: ctx[:to].to_s, subject: ctx[:subject].to_s } }
        window_spec.field :to,      label: 'To'
        window_spec.field :subject, label: 'Subject', max_length: MailService::SUBJECT_MAX
        window_spec.field :body,    type: :textarea, max_length: MailService::BODY_MAX
        window_spec.on_submit do |values, form, ctx|
          from = ctx[:username]
          case ctx[:mail].send_letter(from, values[:to], values[:subject], values[:body],
                                      registered: ctx[:authenticated], session_id: ctx[:session_id])
          when :ok
            ctx[:discord].feedback(from) if ctx[:mail].recipient(values[:to]) == MailService::SYSOP
            ctx[:on_sent]&.call
            BBS::Dialogs.message(ctx[:app], "Your letter is on its way to #{ctx[:mail].recipient(values[:to])}.",
                                 title: ' Sent ')
            :close
          when :unknown  then form.error('No registered name like that. Write to Sysop, or check the User Listing.'); :keep
          when :guest    then form.error('A guest writes only to the Sysop. Register to write to others.'); :keep
          when :empty    then form.error('The letter is empty.'); :keep
          when :too_fast then form.error("One letter every #{MailService::COOLDOWN} seconds, please."); :keep
          else form.error('Call with a name to write letters.'); :keep
          end
        end
      end

      window :voting, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' Voting Booth '
        window_spec.list_width    26
        window_spec.empty_message '  (no polls)'
        window_spec.items         { |ctx| ctx[:voting].polls }
        window_spec.item_label    { |poll, ctx| UI::Formatters::Voting.label(poll, ctx[:voting].ballot(poll, ctx[:username])) }
        window_spec.render_detail do |poll, width, ctx|
          UI::Formatters::Voting.detail(poll, ctx[:voting].results(poll), ctx[:voting].total(poll),
                                        ctx[:voting].ballot(poll, ctx[:username]), width)
        end
        window_spec.bottom_meta   { |_poll, _ctx| '✓ voted   • open   Enter or Vote: cast or change your vote' }
        window_spec.on_activate   { |poll, window, ctx| ctx[:app].vote_on(poll, window) }
        window_spec.action label: '&Vote', align: :left do |window, ctx|
          ctx[:app].vote_on(window.list_widget.selected_item, window)
          :keep
        end
      end

      window :file_areas, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' File Areas '
        window_spec.list_width    32
        window_spec.empty_message '  (the catalog or the FTP server did not answer — try again later)'
        window_spec.items         { |ctx| ctx[:file_areas].areas }
        window_spec.item_label    { |area, _ctx| UI::Formatters::FileAreas.area_label(area) }
        window_spec.render_detail { |area, width, _ctx| UI::Formatters::FileAreas.area_detail(area, width) }
        window_spec.bottom_meta   { |_area, _ctx| 'Enter: open the area' }
        window_spec.on_activate   { |area, _window, ctx| ctx[:app].open_window(:file_area, area: area) }
      end

      window :file_area, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         { |ctx| " Files — #{ctx[:area].title} " }
        window_spec.list_width    37
        window_spec.empty_message '  (no files)'
        window_spec.items         { |ctx| ctx[:area].files }
        window_spec.item_label    { |item, ctx| UI::Formatters::FileAreas.file_label(item, ctx[:file_areas]) }
        window_spec.render_detail do |item, width, ctx|
          UI::Formatters::FileAreas.file_detail(item, width, files: ctx[:files],
                                                             catalog_url: ctx[:games].catalog_url(item.game))
        end
        window_spec.bottom_meta   { |item, _ctx| "#{item.downloads} DLs · Enter: download by ZMODEM" }
        window_spec.on_activate   { |item, _window, ctx| ctx[:app].ftp_download(ctx[:file_areas].entry(item)) }
        window_spec.action label: '&Download', align: :left do |window, ctx|
          item = window.list_widget.selected_item
          ctx[:app].ftp_download(ctx[:file_areas].entry(item)) if item
          :keep
        end
      end

      window :bulletins, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' Bulletins '
        window_spec.list_width    30
        window_spec.items         { |_ctx| UI::Formatters::Bulletins::LIST }
        window_spec.item_label    { |b, _ctx| b[:label] }
        window_spec.render_detail do |b, width, ctx|
          case b[:kind]
          when :logon
            UI::Formatters::Bulletin.body(
              username: ctx[:username] || 'Anonymous', registered: ctx[:authenticated],
              online_count: ctx[:online].count, total_messages: ctx[:boards].total_count,
              recent_callers: ctx[:last_callers].recent(3), releases: ctx[:games].latest_releases(3),
              events: ctx[:site].upcoming_events(2), oneliners: ctx[:oneliners].recent(5)
            ).map { |l|
              if l.is_a?(Hash)
                l[:text]
              else
                (l == :spacer ? '' : " #{l}")
              end
            }
          when :about
            BBS::Markdown.to_lines(ctx[:wiki].content('', lang: ctx[:lang]), width: width - 1, theme: ctx[:app].theme)
          when :history
            UI::Formatters::History.lines(ctx[:games].release_history, width)
          when :events
            events = ctx[:site].upcoming_events(10)
            events.empty? ? ['  (nothing scheduled)'] : events.map { |e| UI::Formatters::News.event_line(e) }
          when :network
            UI::Formatters::Network.body.map { |l| l == :spacer ? '' : l }
          when :file
            BBS::Markdown.to_lines(File.read(File.join(BULLETINS_DIR, b[:file])), width: width - 1, theme: ctx[:app].theme)
          end
        end
      end

      window :howtos, type: :master_detail do |window_spec|
        window_spec.maximizable true
        window_spec.title         ' Tech HowTos '
        window_spec.list_width    { |ctx| [34, ctx[:app].cols / 3].max }
        window_spec.empty_message '  (the how-to feed did not answer — try again later)'
        window_spec.items         { |ctx| ctx[:site].howtos }
        window_spec.item_label    { |h, _ctx| h.title }
        window_spec.render_detail do |h, width, ctx|
          path = h.url.sub(%r{\Ahttps://wiki\.teletypegames\.org/?}, '')
          text = ctx[:wiki].content(path)
          text = "# #{h.title}\n\n#{h.description}" if text.to_s.strip.empty?
          BBS::Markdown.to_lines(text, width: width - 1, theme: ctx[:app].theme)
        end
        window_spec.bottom_meta { |h, _ctx| h.url }
      end

      # ── Menubar ────────────────────────────────────────────────────────────────

      menubar do
        menu '&TTG Master' do
          item '&Ask a question…', shortcut: 'F1' do open_window(:master) end
          separator
          UI::Formatters::Master::QUICK_QUESTIONS.each do |label, question|
            item(label) { open_window(:master, question: question) }
          end
        end

        menu '&File' do
          item '&Welcome'     do open_window(:bulletin) end
          item '&Bulletins…'  do open_window(:bulletins) end
          item '&News'        do open_window(:news) end
          item '&Dev Log'     do open_window(:dev_log) end
          item '&System Info' do open_window(:system_info) end
          item 'BBS Net&work' do open_window(:network) end
          separator
          item '&Log off', shortcut: 'Alt-X' do :halt end
        end

        menu '&Messages' do
          item '&Boards…',   shortcut: 'F2' do open_window(:messages) end
          item '&New Post…', shortcut: 'F3' do open_new_post end
          item '&Mail…',     shortcut: 'F7' do open_mail end
          item '&Oneliners' do open_window(:oneliners) end
          separator
          item '&Live Chat', shortcut: 'F4' do open_window(:chat) end
          separator
          item '&Feedback to the Sysop…' do write_mail(to: MailService::SYSOP) end
          item '&Page the Sysop'         do page_sysop end
        end

        menu '&Content' do
          item '&File Areas'      do open_window(:file_areas) end
          item 'FTP &Browser'     do open_window(:ftp) end
          item '&Game Catalog'    do open_window(:games) end
          separator
          item '&Platform Guides' do open_window(:wiki, section: :platforms) end
          item '&Engines'         do open_window(:wiki, section: :engines) end
          item '&DOS Corner'      do open_window(:wiki, section: :dos) end
          item 'Tech &HowTos'     do open_window(:howtos) end
          separator
          item '&ANSI Gallery' do open_window(:gallery) end
        end

        menu '&Users' do
          item '&Who is Online'  do open_window(:online_users) end
          item '&Last Callers'   do open_window(:last_callers) end
          item '&User Listing'   do open_window(:user_list) end
          item 'Your &Stats'     do open_window(:my_stats) end
          item '&Hall of Fame'   do open_window(:hall_of_fame) end
          item '&Voting Booth'   do open_window(:voting) end
          separator
          item '&Team' do open_window(:team) end
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

        menu '&Doors' do
          doors
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
          item '&Ask the TTG Master', shortcut: 'F1' do open_window(:master) end
          item '&New to BBSes?' do open_window(:bulletins) end
          separator
          item '&About' do
            BBS::Dialogs.message(self,
              'Teletype BBS — the telnet board of Teletype Games, powered by rubbs. ' \
              'Message boards, mail, oneliners, a live chat and a voting booth; our games in the file areas ' \
              'and the catalog, the wiki guides, bulletins and the dev log. ' \
              'Register your name under Users to keep it. Doors: SERMO, a Commodore 64 and a Plus/4, ' \
              'the Impostor debrief terminal, Chat of Ra and TTG Trivia. Lost? F1 asks the TTG Master.',
              title: ' About ', width: 64)
          end
          item '&Keys' do
            BBS::Dialogs.message(self,
              'Alt+letter — open menu · Tab/Shift-Tab — move focus · Enter — activate · ' \
              'Esc — close window · F5 or Alt-Enter — full screen and back (or [↑] on the title bar) · ' \
              'F6 / Shift-F6 or a click — next / previous window, Alt-1…9 — window by its number · ' \
              'Ctrl-F5 — move (arrows) and size (Shift+arrows) a window, or drag its title bar and its ┘ corner · ' \
              'F1 Ask the TTG Master · F2 Boards · F3 Post · F4 Chat · F7 Mail · F10 Menu · Alt-X Log off',
              title: ' Keys ', width: 70)
          end
        end
      end

      status_hint('F1',  'Ask')    { open_window(:master) }
      status_hint('F2',  'Boards') { open_window(:messages) }
      status_hint('F3',  'Post', hidden: true) { open_new_post }
      status_hint('F4',  'Chat')   { open_window(:chat) }
      status_hint('F7',  'Mail')   { open_mail }
      status_hint('F10', 'Menu')   { menubar.open(0) }
      status_hint('Alt-X', 'Bye')  { :halt }

      on_tick do
        top = top_window&.title.to_s.strip
        services[:online].activity(session_id, top.empty? ? 'At the main menu' : top)
        statusbar.right_text = status_text
        context[:ticks] = (context[:ticks] || 0) + 1
        check_mail if (context[:ticks] % 10).zero?
      end

      on_door do |door, ctx|
        online_service.activity(ctx[:session_id], "Door: #{door.label.delete('&')}")
      end

      init do
        name = context[:desktop_art] ||= services[:art].for_caller(context[:authenticated] ? context[:username] : nil)
        lines = name ? services[:art].lines(name) : BBS::Widgets::AnsiArt.default_lines
        @desktop_art = BBS::Widgets::AnsiArt.new(lines: lines)
        @desktop_art.layout(1, 1, cols, rows - 2)
        add(@desktop_art)
        master = BBS::Widgets::Button.new(label: UI::Formatters::Master::DESKTOP_LABEL, on_click: ->(_) { open_window(:master) })
        master.layout(cols - UI::Formatters::Master::DESKTOP_LABEL.length - 5, rows - 2,
                      UI::Formatters::Master::DESKTOP_LABEL.length + 4, 1)
        add(master)
        statusbar.right_text = status_text
        context[:mail_seen] ||= services[:mail].unread_count(context[:username], sysop: sysop?) if registered?
        unless context[:welcomed]
          context[:welcomed] = true
          open_window(:bulletin)
        end
      end
    end
    call do |ctx, runner|
      teletype_app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
      nil
    end
    call do |ctx, runner|
      UI::Formatters::Logon.goodbye(runner, name: ctx[:username] || 'Anonymous',
                                            seconds: Time.now - (ctx[:call_started] || Time.now),
                                            caller_number: ctx[:caller_number] || last_callers_service.caller_number,
                                            quote: UI::Formatters::Taglines.pick(site_service.members))
      nil
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      nil
    end
  end
end

BBS.start
