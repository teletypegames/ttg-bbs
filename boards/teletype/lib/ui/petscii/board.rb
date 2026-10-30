# frozen_string_literal: true

module UI
  module Petscii
    # One call on the C64 board: the main menu and what its keys open. The
    # sections live in messages.rb, content.rb and people.rb.
    class Board
      # Two rows of two sections, each with its colour: the keys of a section
      # wear it, so the eye finds the group first.
      MENU = [
        [['messages', GN, [['m', 'message boards'], %w[e e-mail], %w[o oneliners], ['l', 'live chat'],
                           ['i', 'irc channel'], ['p', 'page the sysop']]],
         ['content', CY, [['f', 'file areas'], ['b', 'ftp browser'], ['g', 'game catalog'], ['w', 'wiki & how-tos'],
                          %w[n news], %w[u bulletins], ['d', 'dev log']]]],
        [['people', PU, [['c', 'callers & users'], ['v', 'voting booth'], ['s', 'you & your name'],
                         ['h', 'hall of fame']]],
         ['more', YE, [%w[r doors], ['t', 'ttg master'], ['y', 'system info'], ['?', 'help'], ['q', 'log off']]]]
      ].freeze
      CELL = 20

      HELP = [
        'Every menu takes one key: the letter in front of the line. RETURN alone does nothing on the main menu.',
        '',
        'Lists are numbered: type the number and RETURN. RETURN alone turns the page, Q goes back. ' \
        'The <- key and RUN/STOP go back too.',
        '',
        'Long texts stop at every screenful: RETURN shows more, Q leaves.',
        '',
        'Posts and letters take several lines: an empty line, or a lone dot, ends the text.',
        '',
        'In the live chat what the others say shows up above your line. An empty line leaves.',
        '',
        'Files cannot come down this line, but each one is on plain HTTP at archive.teletypegames.org, ' \
        'and on ftp.teletypegames.org.',
        '',
        'The board has a modern face too, with windows and ANSI art: call with a PC terminal and choose 1.',
        '',
        'Lost? T asks the TTG Master.'
      ].freeze

      ACTIONS = {
        'm' => :boards, 'e' => :mail, 'o' => :oneliners, 'l' => :live_chat, 'i' => :irc, 'p' => :page_sysop,
        'f' => :file_areas, 'b' => :ftp, 'g' => :games, 'w' => :wiki, 'n' => :news, 'u' => :bulletins,
        'd' => :dev_log, 'c' => :people, 'v' => :voting, 's' => :you, 'h' => :hall_of_fame, 'r' => :doors,
        't' => :master, 'y' => :system_info, '?' => :help, 'z' => :sysop_console
      }.freeze

      def initialize(bbs, screen, ctx)
        @bbs    = bbs
        @screen = screen
        @ctx    = ctx
      end

      def run
        loop do
          doing('At the main menu')
          main_menu
          k = @screen.choose("#{WH}command:#{LG} ", [*ACTIONS.keys, 'q', 'x', :enter], back: :enter)
          next if k == :enter
          return if %w[q x].include?(k) && logoff?

          send(ACTIONS[k]) if ACTIONS[k]
        end
      end

      private

      def name = @ctx[:username] || AccountService::ANONYMOUS
      def registered? = @ctx[:authenticated] == true
      def anonymous? = name == AccountService::ANONYMOUS
      def sysop?     = @bbs.sysop?(name, @ctx[:authenticated])
      def session_id = @ctx[:session_id]

      def doing(text) = @bbs.online.activity(session_id, "#{text} (C64)")

      def node_text
        node = @bbs.online.node(session_id)
        "#{"node #{node.number} " if node}#{Time.now.strftime('%H:%M')}"
      end

      def main_menu
        @unread = registered? ? @bbs.mail.unread_count(name, sysop: sysop?) : nil
        @screen.title('TELETYPE BBS', node_text)
        MENU.each do |left, right|
          left = [left[0], left[1], left[2] + [['z', 'sysop console']]] if sysop? && left[0] == 'people'
          @screen.puts "#{section_head(left)}#{section_head(right)}"
          [left[2].size, right[2].size].max.times do |i|
            @screen.puts "#{menu_cell(left[1], *left[2][i])}#{menu_cell(right[1], *right[2][i])}"
          end
        end
        live_strip
        status
      end

      # A section's name in its colour, the rest of the cell a line.
      def section_head((title, color, _items))
        " #{color}#{title}#{DG} #{'─' * (CELL - title.length - 3)}#{LG}"
      end

      def menu_cell(color, key = nil, label = nil)
        return ' ' * CELL if key.nil?

        label = "#{label} (#{@unread})" if key == 'e' && @unread.to_i.positive?
        " #{color}#{key.upcase}#{LG} #{label[0, CELL - 4].ljust(CELL - 4)} "
      end

      # What is happening, under the menu: the nodes, the boards, the next
      # event and the newest release, one line each.
      def live_strip
        @screen.rule
        online = @bbs.online.count
        mail   = @unread.to_i.positive? ? " #{GR}·#{LG} #{GN}#{@unread} new mail#{LG}" : ''
        @screen.puts " #{YE}#{online}#{LG} on line #{GR}·#{LG} #{YE}#{@bbs.boards.total_count}#{LG} messages#{mail}"
        event = @bbs.site.upcoming_events(1).first
        if event
          days = ((event.date - Time.now) / 86_400).ceil
          when_ = days <= 0 ? 'today' : "in #{days} day#{'s' unless days == 1}"
          @screen.puts " #{GR}next:#{LG} #{event.name[0, 38 - 7 - when_.length - 1]} #{CY}#{when_}#{LG}"
        end
        game = @bbs.games.latest_releases(1).first
        @screen.puts " #{GR}new:#{LG}  #{YE}#{game.title[0, 38 - 7 - game.version.length - 1]}#{LG} #{game.version}" if game
      end

      # Mail that arrived since the last look rings once, as on the old boards.
      def status
        unread = @unread
        seen   = @ctx[:mail_seen] || unread
        @ctx[:mail_seen] = unread
        return unless unread && seen && unread > seen

        @screen.bell
        @screen.puts " #{GN}new mail! e opens your mailbox.#{LG}"
      end

      def logoff?
        @screen.choose("#{WH}log off now? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
      end

      # ── more ───────────────────────────────────────────────────────────

      # Only the doors that fit 40 columns, or have a C64 version; the others
      # wait on the modern face.
      def doors
        doors, wide = @bbs.doors.partition(&:c64?)
        door = @screen.pick('DOORS', doors) { |d| "#{d.title} #{GR}#{d.tag}#{LG}" }
        unless door
          return if wide.empty?

          @screen.title('DOORS')
          @screen.say("#{wide.map(&:title).join(', ')} need 80 columns: call with a PC " \
                      'terminal and choose 1 to open them.', GR)
          return @screen.pause
        end

        doing("Door: #{door.title}")
        BBS::Door.new(door.name, door.petscii || door.program, label: door.label).run(@screen.session, @ctx)
      end

      def master
        doing('Asking the TTG Master')
        @screen.title('ASK THE TTG MASTER')
        @screen.say('Hey, caller! I am the sysop of this board. Ask me where things are, what is new, what is ' \
                    'coming up. An empty line takes you back.', YE)
        loop do
          question = @screen.ask("\r\n#{CY}you:#{LG} ")
          return if question.empty?

          @screen.write "#{DG}thinking...#{LG}"
          reply = @bbs.c64_master.answer(question, @ctx)
          @screen.write "\r#{' ' * 11}\r"
          @screen.say("ttg master: #{reply}", YE)
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
        lines += ['', " #{WH}the boards of teletype games#{LG}"]
        TeletypeBBS::NETWORK.each do |board, address, note|
          lines += ['', " #{YE}#{board}#{LG}", "   #{CY}#{address}#{LG}", *@screen.wrap(note, 35).map { |l| "   #{l}" }]
        end
        lines += ['', " #{GR}in a browser:#{LG}", " #{CY}bbsweb.teletypegames.org#{LG}"]
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
        @bbs.online.nodes.each { |n|
          @screen.puts " #{YE}#{n.number.to_s.rjust(2)}#{LG} #{n.name[0, 16].ljust(17)}#{GR}#{n.activity.to_s[0, 18]}#{LG}"
        }
        text = @screen.ask("\r\n#{WH}broadcast#{LG} (empty: back)\r\n> ")
        @bbs.sysop_broadcast(name, text) unless text.empty?
      end
    end
  end
end
