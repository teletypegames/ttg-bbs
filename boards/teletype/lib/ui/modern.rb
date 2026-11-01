# frozen_string_literal: true

require_relative 'modern/formatters'
require_relative 'modern/classic_formatters'
require_relative 'modern/desktop'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the modem
  # and the logon matrix, then a desktop of windows under a menubar.
  module Modern
    def self.flow(bbs)
      BBS::Flow.define do
        # The old way in: the modem, the board's art, then the name.
        call do |ctx, runner|
          Formatters::Logon.connect(runner)
          logon = TeletypeBBS::LOGON_ART
          art   = File.exist?(logon) ? BBS::Widgets::AnsiArt.load_file(logon) : BBS::Widgets::AnsiArt.default_lines
          Formatters::Logon.matrix(runner, art, caller_number: bbs.last_callers.caller_number,
                                                    nodes: bbs.online.count)
          ctx[:call_started] = Time.now
          nil
        end
        ask :username, prompt: 'Name (blank for Anonymous)',
            transform: ->(value) { AccountService.normalize_name(value) }
        call do |ctx, runner|
          name = ctx[:username]
          ctx[:authenticated] = false
          if bbs.accounts.registered?(name)
            3.times do
              runner.write "  \e[1;37mPassword\e[0m: "
              password = runner.readline(mask: '*')
              break if password.nil?
              if bbs.accounts.authenticate(name, password)
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
          bbs.start_call(ctx[:session_id], name, listed: runner.session.naws_reported?)
          nil
        rescue StandardError => e
          warn "Login error: #{e.class}: #{e.message}"
          :halt
        end
        # The logon sequence: who is calling, then the scans of the old boards.
        call do |ctx, runner|
          summary = bbs.logon_summary(ctx[:username], registered: ctx[:authenticated], session_id: ctx[:session_id])
          ctx[:caller_number] = summary[:caller_number]
          Formatters::Logon.screen(runner, **summary)
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
          bbs.doors.each { |d| door d.name, d.program, label: d.label, hint: d.hint }
          services bbs.services

          helpers do
            def sysop? = services[:bbs].sysop?(context[:username], context[:authenticated])

            def registered? = context[:authenticated] == true

            # Node, clock and time on line, the way the old status lines had them.
            def status_text
              node = services[:online].node(session_id)
              on   = Formatters.duration(Time.now - (context[:call_started] || Time.now))
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
                BBS::Dialogs.message(self, 'Mail belongs to registered names (You > Register…). ' \
                                           'Anyone with a name can write to the sysop: Messages > Feedback to the Sysop.',
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
              if services[:bbs].page_sysop(name)
                BBS::Dialogs.message(self, Formatters::PageSysop.text(true), title: ' Paging the Sysop… ', width: 60)
              else
                BBS::Dialogs.confirm(self, Formatters::PageSysop.text(false), title: ' Paging the Sysop… ',
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
              Formatters::Master.lines('You', question, cols, you: true).each { |line| queue << line }
              if ctx[:master_busy]
                Formatters::Master.lines('TTG Master', 'One question at a time, caller.', cols).each { |line| queue << line }
                return
              end

              ctx[:master_busy] = true
              width = cols
              Thread.new do
                reply = ctx[:master].answer(question, ctx)
                Formatters::Master.lines('TTG Master', reply, width).each { |line| queue << line }
              rescue StandardError => e
                warn "TTG Master: #{e.class}: #{e.message}"
              ensure
                ctx[:master_busy] = false
              end
            end

            # Back to the live desktop: every window closed.
            def show_dashboard
              windows.dup.each { |w| close_window(w) }
              refresh_dashboard
            end

            def refresh_dashboard
              @dashboard.data = Dashboard::Data.new(
                name: context[:username] || AccountService::ANONYMOUS, registered: registered?,
                caller_number: context[:caller_number], node: services[:online].node(session_id)&.number,
                nodes: services[:online].nodes, callers: services[:last_callers].recent(5),
                releases: services[:games].latest_releases(5), events: services[:site].upcoming_events(3),
                oneliners: services[:oneliners].recent(8), messages: services[:boards].total_count
              )
            rescue StandardError => e
              warn "Dashboard: #{e.class}: #{e.message}"
            end
          end

          # ── Windows ────────────────────────────────────────────────────────────────

          window :system_info, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:board]
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
                ['Uptime',       Formatters::SystemInfo.format_uptime(ctx[:uptime])]
              ]
              [{ kv: rows, label_width: 15 }]
            end
          end

          window :messages, type: :master_detail do |window_spec|
            window_spec.accent Accent::STYLES[:messages]
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
              Formatters::Board.lines(ctx[:boards].messages(board.id, 100), board.title, width)
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
            window_spec.accent Accent::STYLES[:messages]
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
                case ctx[:bbs].post_message(ctx[:board], username, values[:body], session_id: ctx[:session_id])
                when :empty
                  form.error('Message cannot be empty.')
                  :keep
                when :too_fast
                  form.error("One post every #{BoardService::COOLDOWN} seconds, please.")
                  :keep
                else
                  ctx[:on_posted]&.call
                  :close
                end
              end
            end
          end

          window :news, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:board]
            window_spec.maximizable true
            window_spec.title  ' News '
            window_spec.width  { |ctx| [ctx[:app].cols - 6, 76].min }
            window_spec.height { |ctx| [ctx[:app].rows - 4, 24].min }
            window_spec.scroll true
            window_spec.body do |ctx|
              Formatters::News.body(
                releases:    ctx[:games].latest_releases(5),
                events:      ctx[:site].upcoming_events(5),
                posts:       ctx[:site].blog_posts(5),
                catalog_url: ->(game) { ctx[:games].catalog_url(game) }
              )
            end
          end

          window :team, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:people]
            window_spec.maximizable true
            window_spec.title  ' The Team '
            window_spec.width  64
            window_spec.height { |ctx| [ctx[:app].rows - 4, 22].min }
            window_spec.scroll true
            window_spec.body   { |ctx| Formatters::Team.body(ctx[:site].members) }
          end

          window :network, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:board]
            window_spec.title  ' BBS Network '
            window_spec.width  72
            window_spec.height { |ctx| [Formatters::Network.body.size + 6, ctx[:app].rows - 3].min }
            window_spec.scroll true
            window_spec.body   { |_ctx| Formatters::Network.body }
          end

          window :register, type: :form do |window_spec|
            window_spec.accent Accent::STYLES[:you]
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
            window_spec.accent Accent::STYLES[:people]
            window_spec.title  ' Who is Online '
            window_spec.width  74
            window_spec.scroll true
            window_spec.height { |ctx| [ctx[:online].count + 8, 10].max }
            window_spec.body   { |ctx| Formatters::Nodes.body(ctx[:online].nodes, ctx[:app].session_id) }
          end

          window :last_callers, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:people]
            window_spec.title  ' Last Callers '
            window_spec.width  64
            window_spec.scroll true
            window_spec.height { |ctx| [ctx[:last_callers].recent(15).size + 6, 10].max }
            window_spec.body   { |ctx| Formatters::Users.last_callers_list(ctx[:last_callers].recent(15)) }
          end

          window :chat, type: :stream do |window_spec|
            window_spec.accent Accent::STYLES[:messages]
            window_spec.maximizable true
            window_spec.title       ' Live Chat '
            window_spec.placeholder 'Type a message and press Enter…'
            window_spec.initial_lines do |ctx|
              ctx[:chat].drain(ctx[:session_id])
              ctx[:chat].history.map { |line| Formatters::Chat.line(line) }
            end
            window_spec.on_submit do |text, _app, ctx|
              ctx[:chat].broadcast(ctx[:username] || 'Anonymous', text.strip) if ctx[:chat].may_speak?(ctx[:session_id])
            end
            window_spec.on_poll do |app_, ctx|
              ctx[:chat].drain(app_.session_id).map { |line| Formatters::Chat.line(line) }
            end
          end

          # The IRC channel, read only: the input line only tells how to join.
          window :irc, type: :stream do |window_spec|
            window_spec.accent Accent::STYLES[:messages]
            window_spec.maximizable true
            window_spec.title       { |ctx| Formatters::Irc.title(ctx[:irc]) }
            window_spec.placeholder Formatters::Irc::PLACEHOLDER
            window_spec.initial_lines do |ctx|
              ctx[:irc].subscribe(ctx[:session_id])
              Formatters::Irc.intro(ctx[:irc]) + ctx[:irc].history.map { |line| Formatters::Irc.line(line) }
            end
            window_spec.on_submit do |_text, _app, ctx|
              ctx[:irc_hint] = true
              nil
            end
            window_spec.on_poll do |app_, ctx|
              hint = ctx.delete(:irc_hint) ? Formatters::Irc.how_to_join(ctx[:irc]) : []
              ctx[:irc].drain(app_.session_id).map { |line| Formatters::Irc.line(line) } + hint
            end
          end

          window :profile, type: :form do |window_spec|
            window_spec.accent Accent::STYLES[:you]
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
            window_spec.accent Accent::STYLES[:messages]
            window_spec.maximizable true
            window_spec.title  ' Oneliners '
            window_spec.width  { |ctx| [ctx[:app].cols - 6, 78].min }
            window_spec.height { |ctx| [ctx[:oneliners].recent(30).size + 6, 10].max }
            window_spec.scroll true
            window_spec.body   { |ctx| Formatters::Oneliners.body(ctx[:oneliners].recent(30)) }
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

          window :dev_log, type: :master_detail do |window_spec|
            window_spec.accent Accent::STYLES[:board]
            window_spec.maximizable true
            window_spec.title         ' Dev Log — git.teletypegames.org '
            window_spec.list_width    36
            window_spec.empty_message '  (no activity, or Gitea did not answer)'
            window_spec.items         { |ctx| ctx[:dev_log].recent(60) }
            window_spec.item_label    { |activity, _ctx| Formatters::DevLog.label(activity) }
            window_spec.render_detail do |activity, width, ctx|
              Formatters::DevLog.detail(activity, width,
                                            commit_url:  ->(sha) { ctx[:dev_log].commit_url(activity, sha) },
                                            release_url: ctx[:dev_log].release_url(activity),
                                            repo_url:    ctx[:dev_log].repo_url(activity))
            end
            window_spec.bottom_meta { |_activity, _ctx| '· push   ◆ tag   ★ release   + repository' }
          end

          window :master, type: :stream do |window_spec|
            window_spec.accent Accent::STYLES[:help]
            window_spec.maximizable true
            window_spec.title       ' Ask the TTG Master '
            window_spec.placeholder 'Ask about the board and press Enter…'
            window_spec.initial_lines do |ctx|
              ctx[:master_queue] = Queue.new
              ctx[:app].ask_master(ctx, ctx[:question]) if ctx[:question]
              Formatters::Master.lines('TTG Master', 'Hey, caller! I am the sysop of this board. Ask me where ' \
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
            window_spec.accent Accent::STYLES[:you]
            window_spec.title  ' Sysop Console '
            window_spec.width  70
            window_spec.height 18
            window_spec.scroll true
            window_spec.body do |ctx|
              Formatters::Sysop.console_body(
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
                                   ctx[:bbs].sysop_broadcast(ctx[:username], text.strip)
                                 end)
              :keep
            end
            window_spec.button label: '&Close', cancel: true
          end

          window :user_list, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:people]
            window_spec.maximizable true
            window_spec.title  ' User Listing '
            window_spec.width  74
            window_spec.scroll true
            window_spec.height { |ctx| (ctx[:accounts].names.size + 9).clamp(10, [ctx[:app].rows - 4, 10].max) }
            window_spec.body do |ctx|
              Formatters::UserList.body(ctx[:bbs].user_rows)
            end
          end

          window :my_stats, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:you]
            window_spec.title  { |ctx| " Your Stats — #{ctx[:username]} " }
            window_spec.width  60
            window_spec.height 16
            window_spec.body do |ctx|
              Formatters::MyStats.body(**ctx[:bbs].my_stats(ctx[:username] || 'Anonymous',
                                                            registered: ctx[:authenticated],
                                                            session_id: ctx[:app].session_id,
                                                            caller_number: ctx[:caller_number],
                                                            sysop: ctx[:app].sysop?))
            end
          end

          window :hall_of_fame, type: :info do |window_spec|
            window_spec.accent Accent::STYLES[:people]
            window_spec.maximizable true
            window_spec.title  ' Hall of Fame '
            window_spec.width  { |ctx| [ctx[:app].cols - 6, 76].min }
            window_spec.height { |ctx| [ctx[:app].rows - 4, 24].min }
            window_spec.scroll true
            window_spec.body do |ctx|
              Formatters::HallOfFame.body(**ctx[:bbs].hall_of_fame, width: [ctx[:app].cols - 6, 76].min - 8)
            end
          end

          window :mail, type: :master_detail do |window_spec|
            window_spec.accent Accent::STYLES[:messages]
            window_spec.maximizable true
            window_spec.title         { |ctx| " Mail — #{ctx[:username]} " }
            window_spec.list_width    36
            window_spec.empty_message { |ctx| Formatters::Mail.empty(ctx[:authenticated]) }
            window_spec.items         { |ctx| ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?) }
            window_spec.item_label    { |letter, _ctx| Formatters::Mail.label(letter) }
            window_spec.render_detail do |letter, width, ctx|
              ctx[:mail].mark_read(letter)
              Formatters::Mail.detail(letter, width)
            end
            window_spec.bottom_meta { |_letter, _ctx| '• unread   Write · Reply · Delete' }
            window_spec.action label: '&Write', align: :left do |window, ctx|
              ctx[:app].write_mail(on_sent: lambda {
                window.replace_items(ctx[:mail].inbox(ctx[:username], sysop: ctx[:app].sysop?))
              })
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
            window_spec.accent Accent::STYLES[:messages]
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
              case ctx[:bbs].send_letter(from, values[:to], values[:subject], values[:body],
                                         registered: ctx[:authenticated], session_id: ctx[:session_id])
              when :ok
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
            window_spec.accent Accent::STYLES[:messages]
            window_spec.maximizable true
            window_spec.title         ' Voting Booth '
            window_spec.list_width    26
            window_spec.empty_message '  (no polls)'
            window_spec.items         { |ctx| ctx[:voting].polls }
            window_spec.item_label    { |poll, ctx| Formatters::Voting.label(poll, ctx[:voting].ballot(poll, ctx[:username])) }
            window_spec.render_detail do |poll, width, ctx|
              Formatters::Voting.detail(poll, ctx[:voting].results(poll), ctx[:voting].total(poll),
                                            ctx[:voting].ballot(poll, ctx[:username]), width)
            end
            window_spec.bottom_meta   { |_poll, _ctx| '✓ voted   • open   Enter or Vote: cast or change your vote' }
            window_spec.on_activate   { |poll, window, ctx| ctx[:app].vote_on(poll, window) }
            window_spec.action label: '&Vote', align: :left do |window, ctx|
              ctx[:app].vote_on(window.list_widget.selected_item, window)
              :keep
            end
          end

          window :bulletins, type: :master_detail do |window_spec|
            window_spec.accent Accent::STYLES[:board]
            window_spec.maximizable true
            window_spec.title         ' Bulletins '
            window_spec.list_width    30
            window_spec.items         { |_ctx| Formatters::Bulletins::LIST }
            window_spec.item_label    { |b, _ctx| b[:label] }
            window_spec.render_detail do |b, width, ctx|
              case b[:kind]
              when :logon
                Formatters::Bulletin.body(**ctx[:bbs].bulletin(ctx[:username], registered: ctx[:authenticated])).map { |l|
                  if l.is_a?(Hash)
                    l[:text]
                  else
                    (l == :spacer ? '' : " #{l}")
                  end
                }
              when :history
                Formatters::History.lines(ctx[:games].release_history, width)
              when :events
                events = ctx[:site].upcoming_events(10)
                events.empty? ? ['  (nothing scheduled)'] : events.map { |e| Formatters::News.event_line(e) }
              when :network
                Formatters::Network.body.map { |l| l == :spacer ? '' : l }
              when :file
                text = File.read(File.join(TeletypeBBS::BULLETINS_DIR, b[:file]))
                BBS::Markdown.to_lines(text, width: width - 1, theme: ctx[:app].theme)
              end
            end
          end

          # Every door with what it is, the way the old boards had a door menu.
          window :doors, type: :master_detail do |window_spec|
            window_spec.accent Accent::STYLES[:doors]
            window_spec.maximizable true
            window_spec.title         ' Door Lobby '
            window_spec.list_width    22
            window_spec.items         { |ctx| ctx[:bbs].doors }
            window_spec.item_label    { |door, _ctx| door.title }
            window_spec.render_detail do |door, width, ctx|
              inside = ctx[:online].nodes.count { |n| n.activity.to_s == "Door: #{door.title}" }
              Formatters::Doors.detail(door, width, inside: inside)
            end
            window_spec.bottom_meta   { |_door, _ctx| 'Enter or Open: step in · leaving the door brings you back' }
            window_spec.on_activate   { |door, _window, ctx| ctx[:app].open_door(door.name) }
            window_spec.action label: '&Open', align: :left do |window, ctx|
              door = window.list_widget.selected_item
              door ? ctx[:app].open_door(door.name) : :keep
            end
          end

          # ── Menubar ────────────────────────────────────────────────────────────────

          menubar do
            menu '&Board' do
              item '&Dashboard', hint: 'The live desktop: who is on, the last callers, what is new and coming up' do
                show_dashboard
              end
              item '&News', hint: 'The latest releases, the coming events and the newest blog posts' do
                open_window(:news)
              end
              item '&Bulletins…', hint: 'Numbered bulletins: the rules, the story so far, New to BBSes?' do
                open_window(:bulletins)
              end
              item 'Dev &Log', hint: 'What the team pushed, tagged and released on git.teletypegames.org' do
                open_window(:dev_log)
              end
              separator
              item '&System Info', hint: 'Nodes, calls, messages and uptime of this board' do
                open_window(:system_info)
              end
              item 'BBS Net&work', hint: 'Our other boards, their telnet addresses, and the board in a browser' do
                open_window(:network)
              end
              separator
              item 'Log &off', shortcut: 'Alt-X', hint: 'Hang up: +++ ATH0 NO CARRIER' do :halt end
            end

            menu '&Messages' do
              item '&Boards…', shortcut: 'F2', hint: 'The message boards: General, Tech, Off-Topic, Sysop' do
                open_window(:messages)
              end
              item '&New Post…', shortcut: 'F3', hint: 'Write a post on the first board' do open_new_post end
              item '&Mail…', shortcut: 'F7', hint: 'Private letters between registered names' do open_mail end
              item '&Oneliners', hint: 'The wall: one line, 64 characters, the newest run along the desktop' do
                open_window(:oneliners)
              end
              separator
              item '&Live Chat', shortcut: 'F4', hint: 'Talk with everyone on the lines now, C64 callers too' do
                open_window(:chat)
              end
              item '&IRC #teletypegames', hint: 'Our channel on Libera.Chat, read only here' do open_window(:irc) end
              item '&Voting Booth', hint: 'The polls of the board, with the results as bars' do
                open_window(:voting)
              end
              separator
              item '&Feedback to the Sysop…', hint: 'A letter to the sysops; anyone with a name may write' do
                write_mail(to: MailService::SYSOP)
              end
              item '&Page the Sysop', hint: 'Ring the bell for a sysop, once a call' do page_sysop end
            end

            menu '&People' do
              item '&Who is Online', hint: 'The nodes: who is on, what they are doing, for how long' do
                open_window(:online_users)
              end
              item '&Last Callers', hint: 'The calls of late, newest first' do open_window(:last_callers) end
              item '&User Listing', hint: 'The registered names with their calls and where they are from' do
                open_window(:user_list)
              end
              item '&Hall of Fame', hint: 'Top downloads, callers, posters and TTG Trivia scores' do
                open_window(:hall_of_fame)
              end
              separator
              item '&Team', hint: 'The members of Teletype Games with their mottos' do open_window(:team) end
            end

            menu '&Doors' do
              item 'Door &Lobby…', hint: 'Every door with what it is and who is inside' do open_window(:doors) end
              separator
              doors
            end

            menu '&You' do
              item 'Your &Stats', hint: 'Your calls, posts, votes and letters' do open_window(:my_stats) end
              item '&Profile…', hint: 'Your signature, location, homepage and notes' do
                if context[:authenticated]
                  open_window(:profile)
                else
                  BBS::Dialogs.message(self, 'Register your name first (You > Register…): ' \
                                             'a profile belongs to a registered name.', title: ' Profile ', width: 60)
                end
              end
              item '&Register…', hint: 'Tie the name you called with to a password' do
                if context[:authenticated]
                  BBS::Dialogs.message(self, "#{context[:username]} is already registered and logged in.", title: ' Register ')
                elsif context[:username] == AccountService::ANONYMOUS
                  BBS::Dialogs.message(self, 'Call again with a name to register it.', title: ' Register ')
                else
                  open_window(:register)
                end
              end
              separator
              item 'Sysop &Console', enabled: -> { sysop? }, hint: 'Stats and broadcasts, for the sysops' do
                open_window(:sysop_console)
              end
            end

            menu '&Help' do
              item '&Ask the TTG Master…', shortcut: 'F1', hint: 'The sysop answers your questions about the board' do
                open_window(:master)
              end
              Formatters::Master::QUICK_QUESTIONS.each do |label, question|
                if question == :network
                  item(label, hint: 'Our other boards: the games and files, the wiki, the blog, the art') do
                    open_window(:network)
                  end
                else
                  item(label, hint: "Ask the TTG Master: #{question}") { open_window(:master, question: question) }
                end
              end
              separator
              item '&New to BBSes?', hint: 'How a board like this works, in a bulletin' do open_window(:bulletins) end
              item '&Keys', hint: 'Every key of the board' do
                BBS::Dialogs.message(self,
                  'Alt+letter — open menu · Tab/Shift-Tab — move focus · Enter — activate · ' \
                  'Esc — close window · F5 or Alt-Enter — full screen and back (or [↑] on the title bar) · ' \
                  'F6 / Shift-F6 or a click — next / previous window, Alt-1…9 — window by its number · ' \
                  'Ctrl-F5 — move (arrows) and size (Shift+arrows) a window, or drag its title bar and its ┘ corner · ' \
                  'F1 Ask the TTG Master · F2 Boards · F3 Post · F4 Chat · F7 Mail · F10 Menu · Alt-X Log off',
                  title: ' Keys ', width: 70)
              end
              item 'A&bout', hint: 'What this board is' do
                BBS::Dialogs.message(self,
                  'Teletype BBS — the telnet clubhouse of Teletype Games, powered by rubbs. ' \
                  'Board: the dashboard, news, bulletins, the dev log. Messages: boards, mail, oneliners, live chat, ' \
                  'IRC and the voting booth. People, Doors, You. Our games and files, the wiki, the blog and the art ' \
                  'have boards of their own: Board > BBS Network. Lost? F1 asks the TTG Master.',
                  title: ' About ', width: 64)
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
            @dashboard.tick!
            refresh_dashboard if (context[:ticks] % 5).zero?
            check_mail if (context[:ticks] % 10).zero?
          end

          on_door do |door, ctx|
            bbs.online.activity(ctx[:session_id], "Door: #{door.label.delete('&')}")
          end

          init do
            @dashboard = Dashboard.new
            add(@dashboard)
            refresh_dashboard
            master = BBS::Widgets::Button.new(label: Formatters::Master::DESKTOP_LABEL, on_click: ->(_) { open_window(:master) })
            master.layout(cols - Formatters::Master::DESKTOP_LABEL.length - 5, rows - 2,
                          Formatters::Master::DESKTOP_LABEL.length + 4, 1)
            add(master)
            statusbar.right_text = status_text
            context[:mail_seen] ||= services[:mail].unread_count(context[:username], sysop: sysop?) if registered?
          end
        end
        call do |ctx, runner|
          teletype_app.run(session: runner.session, session_id: ctx[:session_id], context: ctx)
          nil
        end
        call do |ctx, runner|
          Formatters::Logon.goodbye(runner, name: ctx[:username] || 'Anonymous',
                                                seconds: Time.now - (ctx[:call_started] || Time.now),
                                                caller_number: ctx[:caller_number] || bbs.last_callers.caller_number,
                                                quote: bbs.taglines.pick)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
