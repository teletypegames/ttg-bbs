# frozen_string_literal: true

module UI
  module Petscii
    # One call on the C64 board: the main menu and what its keys open. The
    # sections live in messages.rb, content.rb and people.rb.
    class Board
      # Two rows of two sections, each with its colour: the keys of a section
      # and its bar wear it, so the eye finds the group first. Each item:
      # its key, its label and the line about it under the menu.
      MENU = [
        [['messages', GN, [['m', 'message boards', 'read and post on the boards'],
                           ['e', 'e-mail', 'your letters; feedback to the sysop'],
                           ['o', 'oneliners', 'a line on the wall for every caller'],
                           ['l', 'live chat', 'talk with whoever is on line'],
                           ['i', 'irc channel', 'the irc channel, from a c64'],
                           ['p', 'page the sysop', 'call the sysop to a chat']]],
         ['board', CY, [['u', 'bulletins', 'the bulletins of the board'],
                        ['d', 'dev log', 'what we are making, commit by commit'],
                        ['n', 'network', 'our boards: games, wiki, blog, art']]]],
        [['people', PU, [['c', 'callers & users', 'who is on line, who called'],
                         ['v', 'voting booth', 'the polls of the board'],
                         ['s', 'you & your name', 'your stats, profile and registration'],
                         ['h', 'hall of fame', 'the top callers and posters']]],
         ['more', YE, [['r', 'doors', 'games and programs behind the doors'],
                       ['t', 'ttg master', 'ask the sysop where things are'],
                       ['y', 'system info', 'the numbers of this board'],
                       ['?', 'help', 'how the keys of this board work'],
                       ['q', 'log off', 'hang up. see you on the wire!']]]]
      ].freeze
      SYSOP = ['z', 'sysop console', 'the nodes, a broadcast: sysops only'].freeze
      # The width of the menu: two columns of COLS / 2 less one.
      MENU_WIDTH = COLS - 1

      HELP = [
        'The main menu is the clubhouse: each item a room of the club. CRSR up and down (and left and right) ' \
        'lights a room, RETURN opens it, and the letter in front of a room opens it at once too. ? is this help, ' \
        'Y the system info, and * swaps the pictures for a menu of plain text and back (for a terminal that ' \
        'cannot show the C64 graphics).',
        '',
        'Lists are numbered: CRSR, or type the number, then RETURN. CRSR left and right turn the pages, Q goes ' \
        'back. The <- key and RUN/STOP go back too.',
        '',
        'Long texts stop at every screenful: RETURN shows more, Q leaves.',
        '',
        'Posts and letters take several lines: an empty line, or a lone dot, ends the text.',
        '',
        'In the live chat what the others say shows up above your line. An empty line leaves.',
        '',
        'Our games and files are on the WarpEngine BBS, port 2329: it sends them by XMODEM onto a C64 disk. ' \
        'N, the town map, shows every board of the network.',
        '',
        'The board has a modern face too, with windows: call with a PC terminal and choose 1.',
        '',
        'Lost? T asks the TTG Master.'
      ].freeze

      ACTIONS = {
        'm' => :boards, 'e' => :mail, 'o' => :oneliners, 'l' => :live_chat, 'i' => :irc, 'p' => :page_sysop,
        'n' => :network, 'u' => :bulletins,
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
          k = text_menu? ? main_menu : clubhouse_menu
          next @ctx[:plain] = !text_menu? if k == '*'
          leaving = %w[q x].include?(k) && logoff?
          next unless leaving || ACTIONS[k]

          Clubhouse.text_mode(@screen.session) unless text_menu?
          return if leaving

          send(ACTIONS[k])
        end
      end

      private

      def name = @ctx[:username] || AccountService::ANONYMOUS
      def registered? = @ctx[:authenticated] == true
      def anonymous? = name == AccountService::ANONYMOUS
      def sysop?     = @bbs.sysop?(name, @ctx[:authenticated])
      def session_id = @ctx[:session_id]

      def doing(text) = @bbs.online.activity(session_id, "#{text} (C64)")

      # The lowercase menu of text instead of the clubhouse: chosen with *,
      # or for a caller whose letters come in capitals (UltimateTerm in its
      # ANSI mode swaps the case and cannot show the graphics).
      def text_menu? = @ctx[:plain] == true

      # The main menu as the clubhouse (Clubhouse::MainMenu); the key taken.
      def clubhouse_menu
        @unread = registered? ? @bbs.mail.unread_count(name, sysop: sysop?) : 0
        ring_for_mail
        @lit = Clubhouse::MainMenu.new(@bbs, @screen.session, @ctx).run(lit: @lit, unread: @unread) || @lit
      end

      # New mail since the last look rings once, as on the old boards.
      def ring_for_mail
        seen = @ctx[:mail_seen] || @unread
        @ctx[:mail_seen] = @unread
        @screen.bell if @unread.to_i > seen.to_i
      end

      def node_text
        node = @bbs.online.node(session_id)
        "#{"node #{node.number} " if node}#{Time.now.strftime('%H:%M')}"
      end

      # The front page: the title bar, the caller and what is going on, then
      # the sections as a cursor menu in two columns. The key of the item
      # taken; nil for ← or RUN/STOP.
      def main_menu
        @unread = registered? ? @bbs.mail.unread_count(name, sysop: sysop?) : nil
        @screen.title('TELETYPE BBS', node_text)
        live_strip
        @screen.puts " #{DG}#{'─' * (COLS - 2)}#{LG}"
        items = menu_items
        index = items.index { |i| i.selectable? && i.value == @lit }
        @lit  = @screen.menu(items, columns: 2, height: items.size / 2, index: index, exits: { 'x' => 'x', '*' => '*' },
                                    hint: 'crsr: choose  return: open  *: art')
      end

      # The cells of the menu, down the left column, then down the right: a
      # section's band, its items, then the next section's band level with
      # the one beside it.
      def menu_items
        left, right = MENU.transpose.map do |sections|
          sections.map do |title, color, items|
            items += [SYSOP] if title == 'people' && sysop?
            [band(title, color), *items.map { |k, label, about| item(k, label, about, color) }]
          end
        end
        rows = left.zip(right).map { |l, r| [l.size, r.size].max }
        [left, right].flat_map do |column|
          column.each_with_index.flat_map { |cells, i| cells + Array.new(rows[i] - cells.size) { BBS::Selector.heading } }
        end
      end

      # A section's name on a band of its colour.
      def band(title, color)
        BBS::Selector.heading("#{color}#{RV} #{title} #{RO}#{DG} #{'─' * (MENU_WIDTH / 2)}")
      end

      def item(key, label, about, color)
        if key == 'e' && @unread.to_i.positive?
          label = "#{label} #{GN}#{@unread}#{LG}"
          about = "#{@unread} new letter#{'s' unless @unread == 1}: #{about}"
        end
        BBS::Selector.item(label, key: key, value: key, about: about, color: color)
      end

      # Who is calling and what is happening, over the menu: the caller and
      # the nodes, the next event and the newest post, one line each. New
      # mail since the last look rings once, as on the old boards.
      def live_strip
        online = @bbs.online.count
        seen   = @ctx[:mail_seen] || @unread
        @ctx[:mail_seen] = @unread
        mail = if @unread.to_i.positive?
                 @screen.bell if seen && @unread > seen
                 " #{GR}·#{LG} #{GN}#{@unread} new mail#{LG}"
               else
                 ''
               end
        @screen.puts " #{WH}hi #{name}!#{LG} #{GR}·#{LG} #{YE}#{online}#{LG} on line#{mail}"
        event = @bbs.site.upcoming_events(1).first
        if event
          days = ((event.date - Time.now) / 86_400).ceil
          when_ = days <= 0 ? 'today' : "in #{days} day#{'s' unless days == 1}"
          @screen.puts " #{GR}next:#{LG} #{event.name[0, 38 - 7 - when_.length - 1]} #{CY}#{when_}#{LG}"
        end
        _board, post = @bbs.boards.latest(1).first
        return unless post

        text = "#{post.username}: #{post.text.to_s.gsub(/\s+/, ' ')}"
        @screen.puts " #{GR}new:#{LG}  #{YE}#{text[0, 38 - 7]}#{LG}"
      end

      def logoff?
        return Clubhouse.leave?(@screen) unless text_menu?

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
        @bbs.online.nodes.each { |n|
          @screen.puts " #{YE}#{n.number.to_s.rjust(2)}#{LG} #{n.name[0, 16].ljust(17)}#{GR}#{n.activity.to_s[0, 18]}#{LG}"
        }
        text = @screen.ask("\r\n#{WH}broadcast#{LG} (empty: back)\r\n> ")
        @bbs.sysop_broadcast(name, text) unless text.empty?
      end
    end
  end
end
