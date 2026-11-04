# frozen_string_literal: true

module UI
  class Petscii
    private

    # ── more ───────────────────────────────────────────────────────────

    def trophies
      doing('Hall of Fame')
      Clubhouse::Trophies.show(session, board.hall_of_fame)
    end

    def town_map
      doing('BBS Network')
      Clubhouse::TownMap.new(session, network).run
    end

    # The games room; a C64 door chosen there opens on the text screen.
    def games_room
      doing('Games Room')
      room = scene.scene(name, registered: registered?, sysop: sysop?)
      door = Clubhouse::GamesRoom.new(session, board.doors, room).run
      return unless door

      Clubhouse.text_mode(session)
      step_in(door)
    end

    # Only the doors that fit 40 columns, or have a C64 version; the others
    # wait on the modern face.
    def door_list
      doors, wide = board.doors.partition(&:c64?)
      door = pick('DOORS', doors) { |d| "#{d.title} #{GR}#{d.tag}#{LG}" }
      unless door
        return if wide.empty?

        title('DOORS')
        say(
          "#{wide.map(&:title).join(', ')} need 80 columns: call with a PC " \
          'terminal and choose 1 to open them.',
          color: GR
        )
        return pause
      end

      step_in(door)
    end

    def step_in(door)
      board.enter_door(session_id, door, '(C64)')
      open_door(door)
    end

    def ask_master
      doing('Asking the TTG Master')
      title('ASK THE TTG MASTER')
      say(
        'Hey, caller! I am the sysop of this board. Ask me where things are, what is new, what is ' \
        'coming up. An empty line takes you back.',
        color: YE
      )
      loop do
        question = ask("\r\n#{CY}you:#{LG} ")
        return if question.empty?

        write "#{DG}thinking...#{LG}"
        reply = c64_master.answer(question, context)
        write "\r#{' ' * 11}\r"
        say("ttg master: #{reply}", color: YE)
      end
    end

    def system_info
      doing('System Info')
      rows = [
        ['nodes in use', online.count.to_s],
        ['calls', "#{last_callers.total_calls} (#{last_callers.calls_today} today)"],
        ['messages', boards.total_count.to_s],
        ['boards', boards.boards.size.to_s],
        ['uptime', uptime],
        ['ruby', RUBY_VERSION]
      ]
      lines = rows.map { |k, v| " #{GR}#{k.ljust(13)}#{LG}#{v}" }
      lines += ['', " #{GR}our other boards: n on the main menu#{LG}"]
      page('SYSTEM INFO', lines)
    end

    def uptime
      seconds = (Time.now - TeletypeBBS::STARTED_AT).to_i
      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    end

    def help
      doing('Help')
      page('HELP', HELP.flat_map { |l| l.empty? ? [''] : wrap(l).map { |w| " #{w}" } })
    end

    def sysop_console
      return unless sysop?

      doing('Sysop Console')
      title('SYSOP CONSOLE')
      puts " #{GR}nodes#{LG}      #{online.count}"
      puts " #{GR}messages#{LG}   #{boards.total_count}"
      puts " #{GR}in chat#{LG}    #{chat.subscriber_count}"
      puts
      online.nodes.each { |n| puts node_line(n) }
      text = ask("\r\n#{WH}broadcast#{LG} (empty: back)\r\n> ")
      board.sysop_broadcast(name, text, sysop: sysop?) unless text.empty?
    end

    def node_line(node)
      " #{YE}#{node.number.to_s.rjust(2)}#{LG} #{node.name[0, 16].ljust(17)}#{GR}#{node.activity.to_s[0, 18]}#{LG}"
    end
  end
end
