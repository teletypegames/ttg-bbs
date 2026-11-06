# frozen_string_literal: true

module UI
  module Modern
    # The methods the desktop (a Rubbs::Modern::Application) gets besides its own:
    # what the menus, the status keys and the windows' buttons do.
    module Helpers
      # The rows of the screen the town map's window cannot have: the
      # menubar, the status bar and the window's frame.
      TOWN_CHROME = 4

      def sysop? = board.sysop?(identity)

      def registered? = signed_in?

      def caller_name = identity.name || MemberService::ANONYMOUS

      def anonymous? = caller_name == MemberService::ANONYMOUS

      # Node and time on line; the clock goes before them.
      def status_text
        node = online.node(session_id)
        on   = Formatters.duration(Time.now - (context[:call_started] || Time.now))
        "#{"Node #{node.number} │ " if node}#{on}"
      end

      # The cork board: the board's wall on the network (ttg-common
      # TTG::Wall, in the words of lib/content/wall.yml), on the whole screen.
      def open_wall
        online.activity(session_id, 'The Wall')
        with_line { TTG::Wall.open(session) }
      end

      # The mailbox: a letter to the sysops (ttg-common TTG::Feedback, in the
      # words of lib/content/feedback.yml), on the whole screen; +kind+
      # skips the choice.
      def write_feedback(kind = nil)
        online.activity(session_id, 'Feedback')
        with_line { TTG::Feedback.open(session, kind: kind) }
      end

      # The sysop's bell: a page, a kind of feedback.
      def page_sysop
        session.write("\a")
        write_feedback(:page)
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

      def open_profile
        return show(:profile) if registered?

        message(
          'Register your name first (You > Register…): a profile belongs to a registered name.',
          title: 'Profile',
          width: 60
        )
      end

      def open_register
        return message("#{caller_name} is already registered and logged in.", title: 'Register') if registered?
        return message('Call again with a name to register it.', title: 'Register') if anonymous?

        show(:register)
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
        @scene = scene.scene(sysop: sysop?, actor: Rubbs::Common::Central::Actor.of(session))
        @games_room&.scene = @scene
        dashboard.data = Dashboard::Data.new(
          name:          caller_name,
          registered:    registered?,
          caller_number: context[:caller_number],
          node:          online.node(session_id)&.number,
          scene:         @scene
        )
      rescue StandardError => e
        Rubbs.log('dashboard', e)
      end

      # Once a second: what the caller is doing, the room card; the
      # dashboard every five seconds.
      def tick
        top_window_shown
        context[:ticks] = (context[:ticks] || 0) + 1
        refresh_dashboard if (context[:ticks] % 5).zero?
      end

      # The window on top tells the node's activity and the room card.
      def top_window_shown
        top = Icon.strip(top_window&.title)
        online.activity(session_id, top.empty? ? 'At the main menu' : top)
        dashboard.room = Clubhouse::Cards.room(top)
      end
    end
  end
end
