# frozen_string_literal: true

module UI
  module Modern
    # The menubar of the desktop, one method a menu. The items' blocks run
    # on the Application (Helpers).
    module Menus
      KEYS = 'Alt+letter — open menu · Tab/Shift-Tab — move focus · Enter — activate · ' \
             'Esc — close window · F5 or Alt-Enter — full screen and back (or [↑] on the title bar) · ' \
             'F6 / Shift-F6 or a click — next / previous window, Alt-1…9 — window by its number · ' \
             'Ctrl-F5 — move (arrows) and size (Shift+arrows) a window, or drag its title bar and its ┘ corner · ' \
             'F1 Ask the TTG Master · F2 Boards · F3 Post · F4 Chat · F7 Mail · F10 Menu · Alt-X Log off'
      ABOUT = 'Teletype BBS — the telnet clubhouse of Teletype Games, powered by rubbs. ' \
              'Board: the dashboard, bulletins, the dev log, the BBS Network. Messages: boards, mail, oneliners, ' \
              'live chat, IRC and the voting booth. People, Doors, You. Our games and files, the wiki, the blog ' \
              'and the art have boards of their own: Board > BBS Network. Lost? F1 asks the TTG Master.'
      NETWORK = 'The town map: our other boards, the games and files, the wiki, the blog, the art'

      # Fills the menubar from its MenubarBuilder +bar+.
      def self.define(bar)
        %i[board messages people doors you help].each { |menu| send(menu, bar) }
      end

      def self.board(bar)
        bar.menu '&Board' do
          item('&Dashboard', hint: 'The clubhouse from the street: who is inside, the notice board, the graffiti wall') do
            show_dashboard
          end
          item('&Bulletins…', hint: 'Numbered bulletins: about us, what is coming up, the rules, New to BBSes?') do
            open_window(:bulletins)
          end
          item('Dev &Log', hint: 'What the team pushed, tagged and released on git.teletypegames.org') do
            open_window(:dev_log)
          end
          separator
          item('&System Info', hint: 'Nodes, calls, messages and uptime of this board') { open_window(:system_info) }
          item('BBS Net&work', hint: 'The town map: our other boards, the games, the wiki, the blog, the art') do
            open_town_map
          end
          separator
          item('Log &off', shortcut: 'Alt-X', hint: 'Hang up: +++ ATH0 NO CARRIER') { :halt }
        end
      end

      def self.messages(bar)
        bar.menu '&Messages' do
          item('&Boards…', shortcut: 'F2', hint: 'The message boards: General, Tech, Off-Topic, Sysop') do
            open_window(:messages)
          end
          item('&New Post…', shortcut: 'F3', hint: 'Write a post on the first board') { open_new_post }
          item('&Mail…', shortcut: 'F7', hint: 'Private letters between registered names') { open_mail }
          item('&Oneliners', hint: 'The wall: one line, 64 characters, the newest run along the desktop') do
            open_window(:oneliners)
          end
          separator
          item('&Live Chat', shortcut: 'F4', hint: 'Talk with everyone on the lines now, C64 callers too') do
            open_window(:chat)
          end
          item('&IRC #teletypegames', hint: 'Our channel on Libera.Chat, read only here') { open_window(:irc) }
          item('&Voting Booth', hint: 'The polls of the board, with the results as bars') { open_window(:voting) }
          separator
          Menus.sysop_items(self)
        end
      end

      def self.sysop_items(menu)
        menu.item('&Feedback to the Sysop…', hint: 'A letter to the sysops; anyone with a name may write') do
          write_mail(to: MailService::SYSOP)
        end
        menu.item('&Page the Sysop', hint: 'Ring the bell for a sysop, once a call') { page_sysop }
      end

      def self.people(bar)
        bar.menu '&People' do
          item('&Who is Online', hint: 'The nodes: who is on, what they are doing, for how long') do
            open_window(:online_users)
          end
          item('&Last Callers', hint: 'The calls of late, newest first') { open_window(:last_callers) }
          item('&User Listing', hint: 'The registered names with their calls and where they are from') do
            open_window(:user_list)
          end
          item('&Hall of Fame', hint: 'The trophy case: top callers, top posters and the TTG Trivia records') do
            open_trophies
          end
          separator
          item('&Team', hint: 'The members of Teletype Games with their mottos') { open_window(:team) }
        end
      end

      def self.doors(bar)
        bar.menu '&Doors' do
          item('&Games Room…', hint: 'The games room at the back: the stations, a lamp over each one in use') do
            open_games_room
          end
          item('Door &Lobby…', hint: 'Every door with what it is and who is inside') { open_window(:doors) }
          separator
          doors
        end
      end

      def self.you(bar)
        bar.menu '&You' do
          item('Your &Stats', hint: 'Your calls, posts, votes and letters') { open_window(:my_stats) }
          item('&Profile…', hint: 'Your signature, location, homepage and notes') { open_profile }
          item('&Register…', hint: 'Tie the name you called with to a password') { open_register }
          separator
          item('Sysop &Console', enabled: -> { sysop? }, hint: 'Stats and broadcasts, for the sysops') do
            open_window(:sysop_console)
          end
        end
      end

      def self.help(bar)
        bar.menu '&Help' do
          item('&Ask the TTG Master…', shortcut: 'F1', hint: 'The sysop answers your questions about the board') do
            open_window(:master)
          end
          Menus.quick_questions(self)
          separator
          item('&New to BBSes?', hint: 'How a board like this works, in a bulletin') { open_window(:bulletins) }
          item('&Keys', hint: 'Every key of the board') { tell(KEYS, ' Keys ', width: 70) }
          item('A&bout', hint: 'What this board is') { tell(ABOUT, ' About ', width: 64) }
        end
      end

      def self.quick_questions(menu)
        Formatters::Master::QUICK_QUESTIONS.each do |label, question|
          if question == :network
            menu.item(label, hint: NETWORK) { open_town_map }
          else
            menu.item(label, hint: "Ask the TTG Master: #{question}") { open_window(:master, question: question) }
          end
        end
      end
    end
  end
end
