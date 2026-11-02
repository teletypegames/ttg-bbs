# frozen_string_literal: true

module UI
  module Petscii
    class Board
      private

      # ── more ───────────────────────────────────────────────────────────

      def trophies
        doing('Hall of Fame')
        Clubhouse::Trophies.show(@screen.session, @bbs.hall_of_fame)
      end

      def town_map
        doing('BBS Network')
        Clubhouse::TownMap.new(@screen.session, @bbs.network).run
      end

      # The games room; a C64 door chosen there opens on the text screen.
      def games_room
        doing('Games Room')
        scene = @bbs.scene.scene(name, registered: registered?, sysop: sysop?)
        door = Clubhouse::GamesRoom.new(@screen.session, @bbs.doors, scene).run
        return unless door

        Clubhouse.text_mode(@screen.session)
        doing("Door: #{door.title}")
        BBS::Door.new(door.name, door.petscii || door.program, label: door.label).run(@screen.session, @ctx)
      end

      # Only the doors that fit 40 columns, or have a C64 version; the others
      # wait on the modern face.
      def doors
        doors, wide = @bbs.doors.partition(&:c64?)
        door = @screen.pick('DOORS', doors) { |d| "#{d.title} #{GR}#{d.tag}#{LG}" }
        unless door
          return if wide.empty?

          @screen.title('DOORS')
          @screen.say("#{wide.map(&:title).join(', ')} need 80 columns: call with a PC " \
                      'terminal and choose 1 to open them.', color: GR)
          return @screen.pause
        end

        doing("Door: #{door.title}")
        BBS::Door.new(door.name, door.petscii || door.program, label: door.label).run(@screen.session, @ctx)
      end

      def master
        doing('Asking the TTG Master')
        @screen.title('ASK THE TTG MASTER')
        @screen.say('Hey, caller! I am the sysop of this board. Ask me where things are, what is new, what is ' \
                    'coming up. An empty line takes you back.', color: YE)
        loop do
          question = @screen.ask("\r\n#{CY}you:#{LG} ")
          return if question.empty?

          @screen.write "#{DG}thinking...#{LG}"
          reply = @bbs.c64_master.answer(question, @ctx)
          @screen.write "\r#{' ' * 11}\r"
          @screen.say("ttg master: #{reply}", color: YE)
        end
      end

      def system_info
        doing('System Info')
        rows = [
          ['nodes in use', @bbs.online.count.to_s],
          ['calls', "#{@bbs.last_callers.total_calls} (#{@bbs.last_callers.calls_today} today)"],
          ['messages', @bbs.boards.total_count.to_s],
          ['boards', @bbs.boards.boards.size.to_s],
          ['uptime', uptime],
          ['ruby', RUBY_VERSION]
        ]
        lines = rows.map { |k, v| " #{GR}#{k.ljust(13)}#{LG}#{v}" }
        lines += ['', " #{GR}our other boards: n on the main menu#{LG}"]
        @screen.page('SYSTEM INFO', lines)
      end

      def uptime
        seconds = (Time.now - TeletypeBBS::STARTED_AT).to_i
        "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
      end

      def help
        doing('Help')
        @screen.page('HELP', HELP.flat_map { |l| l.empty? ? [''] : @screen.wrap(l).map { |w| " #{w}" } })
      end

      def sysop_console
        return unless sysop?

        doing('Sysop Console')
        @screen.title('SYSOP CONSOLE')
        @screen.puts " #{GR}nodes#{LG}      #{@bbs.online.count}"
        @screen.puts " #{GR}messages#{LG}   #{@bbs.boards.total_count}"
        @screen.puts " #{GR}in chat#{LG}    #{@bbs.chat.subscriber_count}"
        @screen.puts
        @bbs.online.nodes.each { |n| @screen.puts node_line(n) }
        text = @screen.ask("\r\n#{WH}broadcast#{LG} (empty: back)\r\n> ")
        @bbs.sysop_broadcast(name, text, registered: registered?) unless text.empty?
      end

      def node_line(node)
        " #{YE}#{node.number.to_s.rjust(2)}#{LG} #{node.name[0, 16].ljust(17)}#{GR}#{node.activity.to_s[0, 18]}#{LG}"
      end
    end
  end
end
