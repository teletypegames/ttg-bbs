# frozen_string_literal: true

module UI
  module Modern
    # The menubar of the desktop and the commands behind its keys. The
    # items' blocks run on the Application (Helpers).
    module Menus
      ABOUT = 'Teletype BBS — the telnet clubhouse of Teletype Games, powered by rubbs. ' \
              'Board: the dashboard, bulletins, the dev log, the BBS Network. Messages: the wall, a letter to the ' \
              'sysop, the voting booth and the bell. People, Doors, You. Our games and files, the wiki, the blog ' \
              'and the art have boards of their own: Board > BBS Network. Lost? F1 asks the TTG Master.'
      NETWORK = 'The town map: our other boards, the games and files, the wiki, the blog, the art'

      extend Rubbs::Modern::Part

      command(
        :master,
        '&Ask the TTG Master…',
        key:   'F1',
        hint:  'Ask',
        about: 'The sysop answers your questions about the board'
      ) { open_master }
      command(
        :wall,
        'The &Wall…',
        key:   'F2',
        hint:  'Wall',
        about: 'The cork board of the clubhouse: pin a note, answer one; C64 callers too'
      ) { open_wall }
      command(
        :feedback,
        '&Feedback…',
        key:   'F7',
        hint:  'Feedback',
        about: 'A letter to the sysop: a word, a bug, an idea'
      ) { write_feedback }
      command(:log_off, 'Log &off', key: 'Alt-X', hint: 'Bye', about: 'Hang up: +++ ATH0 NO CARRIER') { log_off }

      menu 'Board' do
        item('&Dashboard', hint: 'The clubhouse from the street: who is inside, the notice board, the graffiti wall') do
          show_dashboard
        end
        item('&Bulletins…', hint: 'Numbered bulletins: about us, what is coming up, the rules, New to BBSes?') do
          show(:bulletins)
        end
        item('Dev &Log', hint: 'What the team pushed, tagged and released on git.teletypegames.org') { show(:dev_log) }
        separator
        item('&System Info', hint: 'Nodes, calls, messages and uptime of this board') { show(:system_info) }
        item('BBS Net&work', hint: 'The town map: our other boards, the games, the wiki, the blog, the art') do
          open_town_map
        end
        separator
        command :log_off
      end

      menu 'Messages' do
        command :wall
        command :feedback
        item('&Voting Booth', hint: 'The polls of the board, with the results as bars') { show(:voting) }
        separator
        item('&Page the Sysop…', hint: 'Ring the bell for the sysops, with a line on what you need') { page_sysop }
      end

      menu 'People' do
        item('&Who is Online', hint: 'The nodes: who is on, what they are doing, for how long') { show(:online_users) }
        item('&Last Callers', hint: 'The calls of late, newest first') { show(:last_callers) }
        item('&User Listing', hint: 'The registered names with their calls and where they are from') { show(:user_list) }
        item('&Hall of Fame', hint: 'The trophy case: top callers, the names most on the wall, the TTG Trivia records') do
          open_trophies
        end
        separator
        item('&Team', hint: 'The members of Teletype Games with their mottos') { show(:team) }
      end

      menu 'Doors' do
        item('&Games Room…', hint: 'The games room at the back: the stations, a lamp over each one in use') do
          open_games_room
        end
        item('Door &Lobby…', hint: 'Every door with what it is and who is inside') { show(:doors) }
        separator
        doors
      end

      menu 'You' do
        item('Your &Stats', hint: 'Your calls and votes') { show(:my_stats) }
        item('&Profile…', hint: 'Your signature, location, homepage and notes') { open_profile }
        item('&Register…', hint: 'Tie the name you called with to a password') { open_register }
        separator
        item('Sysop &Console', enabled: -> { sysop? }, hint: 'The nodes and the numbers, for the sysops') do
          show(:sysop_console)
        end
      end

      help(about: ABOUT) do
        command :master
        Formatters::Master::QUICK_QUESTIONS.each do |label, question|
          next item(label, hint: NETWORK) { open_town_map } if question == :network

          item(label, hint: "Ask the TTG Master: #{question}") { open_master(question) }
        end
        separator
        item('&New to BBSes?', hint: 'How a board like this works, in a bulletin') { show(:bulletins) }
        separator
      end
    end
  end
end
