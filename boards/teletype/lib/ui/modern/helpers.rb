# frozen_string_literal: true

module UI
  module Modern
    # The methods the desktop (a BBS::Application) gets besides its own:
    # what the menus, the status keys and the windows' buttons do.
    module Helpers
      # The rows of the screen the town map's window cannot have: the
      # menubar, the status bar and the window's frame.
      TOWN_CHROME = 4

      def sysop? = services[:bbs].sysop?(context[:username], context[:authenticated])

      def registered? = context[:authenticated] == true

      def caller_name = context[:username] || AccountService::ANONYMOUS

      # Node, clock and time on line, the way the old status lines had them.
      def status_text
        node = services[:online].node(session_id)
        on   = Formatters.duration(Time.now - (context[:call_started] || Time.now))
        "#{"Node #{node.number} │ " if node}#{Time.now.strftime('%H:%M')} │ #{on}"
      end

      def tell(text, title, **) = BBS::Dialogs.message(self, text, title: title, **)

      # Mail that arrives during a call rings once, the way it used to.
      def check_mail
        return unless registered?

        unread = services[:mail].unread_count(context[:username], sysop: sysop?)
        known  = context[:mail_seen] || unread
        context[:mail_seen] = unread
        return unless unread > known

        session.write("\a")
        tell("New mail! You have #{unread} unread letter#{'s' if unread != 1}: Messages > Mail.", ' Mail ')
      end

      def open_mail
        return open_window(:mail) if registered? || sysop?

        tell('Mail belongs to registered names (You > Register…). ' \
             'Anyone with a name can write to the sysop: Messages > Feedback to the Sysop.', ' Mail ', width: 60)
      end

      def write_mail(to: '', subject: '', on_sent: nil)
        return tell('Call again with a name to write letters.', ' Mail ') if caller_name == AccountService::ANONYMOUS

        open_window(:compose_mail, to: to, subject: subject, on_sent: on_sent)
      end

      def page_sysop
        return tell('The bell has rung already this call. Leave a letter instead.', ' Page ') if context[:paged]

        context[:paged] = true
        session.write("\a")
        if services[:bbs].page_sysop(caller_name)
          BBS::Dialogs.message(self, Formatters::PageSysop.text(true), title: ' Paging the Sysop… ', width: 60)
        else
          BBS::Dialogs.confirm(self, Formatters::PageSysop.text(false), title: ' Paging the Sysop… ',
                                     on_yes: -> { write_mail(to: MailService::SYSOP, subject: 'Page') })
        end
      end

      def vote_on(poll, window = nil)
        return unless poll
        return tell('Call again with a name to vote.', ' Voting Booth ') if caller_name == AccountService::ANONYMOUS

        BBS::Dialogs.input(self, prompt: "The number of your choice, 1 to #{poll.options.size}:",
                                 title: ' Your vote ', width: 56,
                                 on_submit: ->(text) { cast_vote(poll, text, window) })
      end

      def cast_vote(poll, text, window)
        option = poll.options[text.to_i - 1] if text.to_i.positive?
        unless option && services[:voting].vote(poll, caller_name, option) == :ok
          return tell("Type a number from 1 to #{poll.options.size}.", ' Voting Booth ')
        end

        window&.reload_detail
        tell("Your vote: #{option}.", ' Voting Booth ')
      end

      def write_oneliner(window)
        BBS::Dialogs.input(self, prompt: "Your line on the wall (#{OnelinerService::MAX_LENGTH} characters at most):",
                                 title: ' Oneliner ', width: 74,
                                 on_submit: ->(text) { add_oneliner(window, text) })
      end

      def add_oneliner(window, text)
        result = services[:oneliners].add(context[:username], text, caller_key: context[:caller_key])
        return tell(Wording::ONELINER[result], ' Oneliners ') if Wording::ONELINER.key?(result)
        return unless result == :ok

        close_window(window)
        open_window(:oneliners)
      end

      def open_new_post
        board = services[:boards].boards.first
        return tell('Select a board first.', ' Compose ') unless board

        open_window(:compose_message, board: board)
      end

      def open_profile
        return open_window(:profile) if registered?

        tell('Register your name first (You > Register…): a profile belongs to a registered name.',
             ' Profile ', width: 60)
      end

      def open_register
        return tell("#{context[:username]} is already registered and logged in.", ' Register ') if registered?
        return tell('Call again with a name to register it.', ' Register ') if caller_name == AccountService::ANONYMOUS

        open_window(:register)
      end

      def sysop_broadcast
        BBS::Dialogs.input(self, prompt: 'Sysop broadcast message:', title: ' Broadcast ', width: 64,
                                 on_submit: lambda { |text|
                                   services[:bbs].sysop_broadcast(context[:username], text, registered: registered?)
                                 })
      end

      # The TTG Master answers in a thread of his own and the window picks the
      # reply up on its next tick, so the board never waits for the model.
      def ask_master(ctx, question)
        queue = ctx[:master_queue]
        Formatters::Master.lines('You', question, cols, you: true).each { |line| queue << line }
        return master_says(queue, 'One question at a time, caller.', cols) if ctx[:master_busy]

        ctx[:master_busy] = true
        width = cols
        Thread.new do
          master_says(queue, ctx[:master].answer(question, ctx), width)
        rescue StandardError => e
          BBS.log('TTG Master', e)
        ensure
          ctx[:master_busy] = false
        end
      end

      def master_says(queue, text, width)
        Formatters::Master.lines('TTG Master', text, width).each { |line| queue << line }
      end

      # The town map (the BBS Network); on a terminal under 80 columns the
      # list of the boards in the Bulletins.
      def open_town_map
        return open_window(:bulletins) if cols < 80

        PictureWindow.open(self, TownMap.new(network: services[:network], rows: rows - TOWN_CHROME),
                           title: Icon.title(:board, 'Town Map — the BBS Network'), accent: Accent::STYLES[:board])
      end

      # The trophy case; the Hall of Fame as lists under 80 columns.
      def open_trophies
        return open_window(:hall_of_fame) if cols < 80

        PictureWindow.open(self, Clubhouse::Trophies.new(fame: services[:bbs].hall_of_fame),
                           title: Icon.title(:people, 'Trophy Case — the Hall of Fame'),
                           accent: Accent::STYLES[:people])
      end

      # The games room (the doors as stations); the Door Lobby under 80 columns.
      def open_games_room
        return open_window(:doors) if cols < 80

        room = GamesRoom.new(doors: services[:bbs].doors, scene: @scene, on_open: ->(door) { open_door(door.name) })
        @games_room = room
        PictureWindow.open(self, room, title: Icon.title(:doors, 'Games Room'), accent: Accent::STYLES[:doors])
      end

      # Back to the live desktop: every window closed.
      def show_dashboard
        windows.dup.each { |w| close_window(w) }
        refresh_dashboard
      end

      def refresh_dashboard
        @scene = services[:scene].scene(caller_name, registered: registered?, sysop: sysop?)
        @games_room&.scene = @scene
        @dashboard.data = Dashboard::Data.new(
          name: caller_name, registered: registered?, caller_number: context[:caller_number],
          node: services[:online].node(session_id)&.number, scene: @scene
        )
      rescue StandardError => e
        BBS.log('dashboard', e)
      end

      # Once a second: what the caller is doing, the room card, the clock;
      # the dashboard every five seconds, the mailbox every ten.
      def tick
        top_window_shown
        statusbar.right_text = status_text
        context[:ticks] = (context[:ticks] || 0) + 1
        @dashboard.tick!
        refresh_dashboard if (context[:ticks] % 5).zero?
        check_mail if (context[:ticks] % 10).zero?
      end

      # The window on top tells the node's activity and the room card.
      def top_window_shown
        top = Icon.strip(top_window&.title)
        services[:online].activity(session_id, top.empty? ? 'At the main menu' : top)
        @dashboard.room = Clubhouse::Cards.room(top)
      end

      # The desktop at the start: the dashboard, the Ask button, the clock.
      def furnish
        @dashboard = Dashboard.new
        add(@dashboard)
        refresh_dashboard
        add(master_button)
        statusbar.right_text = status_text
        context[:mail_seen] ||= services[:mail].unread_count(context[:username], sysop: sysop?) if registered?
      end

      def master_button
        label = Formatters::Master::DESKTOP_LABEL
        BBS::Widgets::Button.new(label: label, on_click: ->(_) { open_window(:master) }).tap do |button|
          button.layout(cols - label.length - 5, rows - 2, label.length + 4, 1)
        end
      end
    end
  end
end
