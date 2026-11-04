# frozen_string_literal: true

module UI
  module Modern
    # The methods the desktop (a BBS::Application) gets besides its own:
    # what the menus, the status keys and the windows' buttons do.
    module Helpers
      # The rows of the screen the town map's window cannot have: the
      # menubar, the status bar and the window's frame.
      TOWN_CHROME = 4

      def sysop? = board.sysop?(context[:username], context[:authenticated])

      def registered? = context[:authenticated] == true

      def caller_name = context[:username] || AccountService::ANONYMOUS

      def anonymous? = caller_name == AccountService::ANONYMOUS

      # Node and time on line; the clock goes before them.
      def status_text
        node = online.node(session_id)
        on   = Formatters.duration(Time.now - (context[:call_started] || Time.now))
        "#{"Node #{node.number} │ " if node}#{on}"
      end

      # Mail that arrives during a call rings once, the way it used to.
      def check_mail
        return unless registered?

        unread = mail.unread_count(context[:username], sysop: sysop?)
        known  = context[:mail_seen] || unread
        context[:mail_seen] = unread
        return unless unread > known

        session.write("\a")
        message("New mail! You have #{unread} unread letter#{'s' if unread != 1}: Messages > Mail.", title: 'Mail')
      end

      def open_mail
        return show(:mail) if registered? || sysop?

        message(
          'Mail belongs to registered names (You > Register…). ' \
          'Anyone with a name can write to the sysop: Messages > Feedback to the Sysop.',
          title: 'Mail',
          width: 60
        )
      end

      def write_mail(to: '', subject: '', on_sent: nil)
        return message('Call again with a name to write letters.', title: 'Mail') if anonymous?

        show(:compose_mail, to: to, subject: subject, on_sent: on_sent)
      end

      def page_sysop
        return message('The bell has rung already this call. Leave a letter instead.', title: 'Page') if context[:paged]

        context[:paged] = true
        session.write("\a")
        return message(Formatters::PageSysop.text(true), title: 'Paging the Sysop…', width: 60) if board.page_sysop(caller_name)

        confirm(Formatters::PageSysop.text(false), title: 'Paging the Sysop…') do
          write_mail(to: MailService::SYSOP, subject: 'Page')
        end
      end

      def vote_on(poll, window = nil)
        return message('Call again with a name to vote.', title: 'Voting Booth') if anonymous?

        ask("The number of your choice, 1 to #{poll.options.size}:", title: 'Your vote', width: 56) do |text|
          cast_vote(poll, text, window)
        end
      end

      def cast_vote(poll, text, window)
        option = poll.options[text.to_i - 1] if text.to_i.positive?
        unless option && voting.vote(poll, caller_name, option) == :ok
          return message("Type a number from 1 to #{poll.options.size}.", title: 'Voting Booth')
        end

        window&.reload_detail
        message("Your vote: #{option}.", title: 'Voting Booth')
      end

      def write_oneliner(window)
        ask(
          "Your line on the wall (#{OnelinerService::MAX_LENGTH} characters at most):",
          title: 'Oneliner',
          width: 74
        ) do |text|
          next unless report(
            oneliners.add(context[:username], text, caller_key: caller_key),
            Wording::ONELINER,
            title: 'Oneliners'
          ) == :ok

          close_window(window)
          show(:oneliners)
        end
      end

      def open_new_post
        first = boards.boards.first
        return message('Select a board first.', title: 'Compose') unless first

        show(:compose_message, message_board: first)
      end

      def open_profile
        return show(:profile) if registered?

        message(
          'Register your name first (You > Register…): a profile belongs to a registered name.',
          title: 'Profile',
          width: 60
        )
      end

      def open_register
        return message("#{context[:username]} is already registered and logged in.", title: 'Register') if registered?
        return message('Call again with a name to register it.', title: 'Register') if anonymous?

        show(:register)
      end

      def sysop_broadcast
        ask('Sysop broadcast message:', title: 'Broadcast', width: 64) do |text|
          board.sysop_broadcast(context[:username], text, registered: registered?)
        end
      end

      # The town map (the BBS Network); on a terminal under 80 columns the
      # list of the boards in the Bulletins.
      def open_town_map
        return show(:bulletins) if cols < 80

        PictureWindow.open(
          self,
          TownMap.new(network: network, rows: rows - TOWN_CHROME),
          title:   'Town Map — the BBS Network',
          section: :board
        )
      end

      # The trophy case; the Hall of Fame as lists under 80 columns.
      def open_trophies
        return show(:hall_of_fame) if cols < 80

        PictureWindow.open(
          self,
          Clubhouse::Trophies.new(fame: board.hall_of_fame),
          title:   'Trophy Case — the Hall of Fame',
          section: :people
        )
      end

      # The games room (the doors as stations); the Door Lobby under 80 columns.
      def open_games_room
        return show(:doors) if cols < 80

        @games_room = GamesRoom.new(doors: board.doors, scene: @scene, on_open: ->(door) { open_door(door.name) })
        PictureWindow.open(self, @games_room, title: 'Games Room', section: :doors)
      end

      # Back to the live desktop: every window closed.
      def show_dashboard
        close_all
        refresh_dashboard
      end

      # The clubhouse from the street, the desktop's widget.
      def dashboard = desktop.widget

      def refresh_dashboard
        @scene = scene.scene(caller_name, registered: registered?, sysop: sysop?)
        @games_room&.scene = @scene
        dashboard.data = Dashboard::Data.new(
          name:          caller_name,
          registered:    registered?,
          caller_number: context[:caller_number],
          node:          online.node(session_id)&.number,
          scene:         @scene
        )
      rescue StandardError => e
        BBS.log('dashboard', e)
      end

      # Once a second: what the caller is doing, the room card; the
      # dashboard every five seconds, the mailbox every ten.
      def tick
        top_window_shown
        context[:ticks] = (context[:ticks] || 0) + 1
        refresh_dashboard if (context[:ticks] % 5).zero?
        check_mail if (context[:ticks] % 10).zero?
      end

      # The window on top tells the node's activity and the room card.
      def top_window_shown
        top = Icon.strip(top_window&.title)
        online.activity(session_id, top.empty? ? 'At the main menu' : top)
        dashboard.room = Clubhouse::Cards.room(top)
      end

      # The mailbox as it is at the start, so only new mail rings.
      def count_mail
        context[:mail_seen] ||= mail.unread_count(context[:username], sysop: sysop?) if registered?
      end
    end
  end
end
