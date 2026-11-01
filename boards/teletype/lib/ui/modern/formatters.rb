# frozen_string_literal: true

# Pure view-layer helpers used by the window DSL in lib/ui/modern.rb. No business
# logic here — each method takes data + width and returns lines/strings.
module UI
  module Modern
    module Formatters
      module Bulletin
        BANNER = Logo.half_blocks.map { |l| "  #{l}" }.freeze

        def self.body(username:, registered:, online_count:, total_messages:,
                      recent_callers:, posts:, events:, oneliners:)
          callers = recent_callers.map do |c|
            "  · #{c.username}  \e[2;37m#{c.timestamp[0, 16].sub('T', ' ')}\e[0m"
          end
          status = if registered then ''
                   elsif username == 'Anonymous' then "  \e[2;37m(call with a name to register it)\e[0m"
                   else "  \e[2;37m(guest — You > Register keeps your name)\e[0m"
                   end
          [
            *BANNER,
            :spacer,
            "Logged in as \e[1;33m#{username}\e[0m#{status}",
            "Online now: #{online_count}   Messages: #{total_messages}",
            :spacer,
            { text: 'Lost? Press F1: the TTG Master, the sysop, answers your questions.', style: :accent },
            :spacer,
            'New on the boards:',
            *(posts.empty? ? ['  (nothing posted yet — Messages > Boards)'] : posts.map { |b, m| Posts.line(b, m) }),
            :spacer,
            'Coming up:',
            *(events.empty? ? ['  (nothing scheduled)'] : events.map { |e| Events.line(e) }),
            :spacer,
            'Last callers:',
            *(callers.empty? ? ['  (none yet)'] : callers),
            :spacer,
            'Oneliners:',
            *(oneliners.empty? ? ['  (the wall is empty — Messages > Oneliners)'] : Oneliners.lines(oneliners))
          ]
        end
      end

      module Oneliners
        def self.lines(oneliners)
          oneliners.map { |o| "  \e[1;33m#{o.username}\e[0m: #{o.text}" }
        end

        def self.body(oneliners)
          return ['  (nobody has written on the wall yet — be the first)'] if oneliners.empty?

          oneliners.map do |o|
            "  \e[2;37m#{o.timestamp.to_s[5, 11].sub('T', ' ')}\e[0m  \e[1;33m#{o.username}\e[0m: #{o.text}"
          end
        end
      end

      module DevLog
        MARKS = { push: '·', tag: '◆', release: '★', repo: '+' }.freeze

        def self.label(activity)
          "#{MARKS[activity.kind]} #{activity.created_at.localtime.strftime('%m-%d')} #{activity.repo}"
        end

        def self.summary(activity)
          case activity.kind
          when :push
            n = activity.commits.size
            "#{activity.user} pushed #{n} commit#{'s' if n != 1} to #{activity.ref}"
          when :tag     then "#{activity.user} tagged #{activity.ref}"
          when :release then "#{activity.user} released #{activity.title.empty? ? activity.ref : activity.title}"
          when :repo    then "#{activity.user}: new or moved repository"
          end
        end

        # Commit messages without their trailers (Co-Authored-By and the like).
        def self.message_lines(message, width)
          body = message.lines.grep_v(/\A[\w-]+-By: /).join.rstrip
          body.split("\n").flat_map { |l| l.strip.empty? ? [''] : BBS::FrameBuffer.wrap_ansi(l, width - 6).map { |w| "    #{w}" } }
        end

        def self.detail(activity, width, commit_url:, release_url:, repo_url:)
          lines = ["  \e[1;33m#{activity.repo}\e[0m", "  \e[0;36m#{summary(activity)}\e[0m",
                   "  \e[2;37m#{activity.created_at.localtime.strftime('%Y-%m-%d %H:%M')}\e[0m", '']
          if activity.kind == :release
            lines << "  \e[1;36m#{release_url}\e[0m"
            lines << ''
          end
          activity.commits.each do |sha, message|
            lines << "  \e[1;37m#{sha[0, 7]}\e[0m"
            lines << "  \e[1;36m#{commit_url.call(sha)}\e[0m"
            lines.concat(message_lines(message, width))
            lines << ''
          end
          lines << "  \e[1;36m#{repo_url}\e[0m" if activity.commits.empty?
          lines
        end
      end

      module Master
        DESKTOP_LABEL = 'F1 ▸ Lost? Ask the TTG Master'

        # A question for the TTG Master, or :network, the BBS Network window.
        QUICK_QUESTIONS = [
          ['What is &coming up?', 'What events are coming up?'],
          ['&Where do I start?', 'I am new here. Where do I start?'],
          ['Where are the &games, files, wiki?', :network],
          ['Which &doors are there?', 'Which doors are there?']
        ].freeze

        # One speaker's turn, wrapped to the Stream window (cols - 8 wide, a
        # border and a scrollbar inside).
        def self.lines(who, text, cols, you: false)
          color = you ? "\e[1;36m" : "\e[1;33m"
          width = [cols - 14, 20].max
          BBS::FrameBuffer.wrap_ansi("#{color}#{who}\e[0m: #{text}", width).map { |l| "  #{l}" } + ['']
        end
      end

      module Events
        def self.line(event)
          "  · #{event.date.strftime('%Y-%m-%d')}  #{event.name}"
        end
      end

      module Posts
        # A post in one line: the board, the writer, the start of the text.
        def self.line(board, message)
          text = message.text.to_s.gsub(/\s+/, ' ')
          "  · \e[1;33m#{message.username}\e[0m on #{board.title}: #{text[0, 48]}#{'…' if text.length > 48}"
        end
      end

      module Team
        def self.body(members, width: 56)
          return ['  (team list unavailable)'] if members.empty?

          members.flat_map do |m|
            motto = BBS::FrameBuffer.wrap_ansi(m.motto, width).map { |l| "    #{l}" }
            ["  \e[1;33m#{m.nick}\e[0m  \e[2;37m#{m.real_nick}\e[0m", *motto, :spacer]
          end
        end
      end

      # A door in the Door Lobby: its name on a bar of the doors' colour, what
      # it is, and the facts a caller wants before stepping in.
      module Doors
        def self.detail(door, width, inside:)
          inner = [width - 4, 10].max
          bar   = " #{door.title} "[0, inner].ljust(inner)
          screen = if door.cols <= 40 then '40 columns: on the C64 face too'
                   elsif door.petscii then '80 columns, with a C64 version on the C64 face'
                   else '80 columns: the modern face only'
                   end
          [
            "  \e[0;38;5;16;48;5;209m#{bar}\e[0m",
            '',
            *BBS::FrameBuffer.wrap_ansi(door.about.to_s, inner).map { |l| "  #{l}" },
            '',
            "  \e[2;37mscreen\e[0m   #{screen}",
            "  \e[2;37minside\e[0m   #{inside.zero? ? 'nobody right now' : "#{inside} caller#{'s' if inside != 1}"}",
            '',
            "  \e[1;33mEnter\e[0m or \e[1;33mOpen\e[0m steps in."
          ]
        end
      end

      module Network
        # The boards of the network as a list (+boards+: NetworkBoardModel,
        # this one first): the bulletin of the network.
        def self.body(boards)
          rows = boards.flat_map do |b|
            ["  \e[1;33m#{b.name.ljust(15)}\e[0m \e[1;36m#{b.address}\e[0m", "  #{' ' * 16}#{b.about}"]
          end
          ['  Each kind of thing has a board of its own: our games and files,',
           '  the wiki, the blog and the art. TTG Gate BBS dials them all.',
           :spacer, *rows, :spacer, '  What each door here is: Doors > Door Lobby.',
           :spacer, '  In a browser, no telnet client needed:',
           "  \e[1;36mhttps://bbsweb.teletypegames.org\e[0m",
           '  The whole FTP tree on plain HTTP, for old machines:',
           "  \e[1;36mhttp://archive.teletypegames.org\e[0m"]
        end
      end

      module SystemInfo
        def self.format_uptime(start)
          return '–' unless start
          seconds = (Time.now - start).to_i
          h = seconds / 3600
          m = (seconds % 3600) / 60
          s = seconds % 60
          "#{h}h #{m}m #{s}s"
        end
      end

      # A board as a message base: a header line, then each message under its
      # number, author and date, its text indented, a thin line between.
      module Board
        def self.lines(messages, board_title, width)
          return ["  (no messages on #{board_title} yet — New starts one)"] if messages.empty?

          inner = [width - 3, 10].max
          head  = " #{board_title} · #{messages.size} message#{'s' if messages.size != 1} "[0, inner].ljust(inner)
          lines = ["\e[0;38;5;16;48;5;78m#{head}\e[0m", '']
          messages.each_with_index do |m, i|
            stamp = m.timestamp.to_s
            left  = "\e[0;38;5;78m##{i + 1}\e[0m \e[1;33m#{m.username}\e[0m"
            pad   = [inner - BBS::FrameBuffer.visible_width(left) - stamp.length, 1].max
            lines << "#{left}#{' ' * pad}\e[2;37m#{stamp}\e[0m"
            m.text.to_s.split("\n").each do |text|
              BBS::FrameBuffer.wrap_ansi(text, inner - 2).each { |l| lines << "  #{l}" }
            end
            lines << "\e[2;37m#{'┄' * inner}\e[0m" unless i == messages.size - 1
          end
          lines
        end
      end

      module Chat
        def self.line(entry)
          "  \e[2;37m#{entry.timestamp}\e[0m  \e[1;33m#{entry.username}\e[0m: #{entry.text}"
        end
      end

      module Irc
        NETWORK     = 'Libera.Chat'
        HOST        = 'irc.libera.chat'
        WEBCHAT     = 'https://web.libera.chat/'
        PLACEHOLDER = 'Read only here. To talk, join the channel from an IRC client (see the top).'

        def self.title(irc) = Icon.title(:messages, "IRC — #{irc.channel} on #{NETWORK}")

        def self.intro(irc)
          [
            "  \e[1;36mA read-only window on #{irc.channel} at #{NETWORK}:\e[0m " \
            "the board listens there as \e[1;33m#{irc.nick}\e[0m.",
            "  To talk, join with any IRC client: \e[1;37m#{HOST}\e[0m, port \e[1;37m6697\e[0m (TLS), " \
            "channel \e[1;37m#{irc.channel}\e[0m",
            "  or in a browser: \e[1;37m#{WEBCHAT}#{irc.channel}\e[0m",
            "  #{status(irc)}",
            ''
          ]
        end

        def self.status(irc)
          return "\e[1;31mNot connected right now, reconnecting…\e[0m" unless irc.joined?

          topic = irc.topic.to_s.empty? ? '' : " · Topic: #{irc.topic}"
          "\e[2;37m#{irc.member_count} on the channel#{topic}\e[0m"
        end

        def self.line(entry)
          if entry.username == IrcRelay::SYSTEM
            "  \e[2;37m#{entry.timestamp}  * #{entry.text}\e[0m"
          else
            "  \e[2;37m#{entry.timestamp}\e[0m  \e[1;36m<#{entry.username}>\e[0m #{entry.text}"
          end
        end

        def self.how_to_join(irc)
          ["  \e[1;33mThe board only reads the channel. Say it on IRC: #{HOST} #{irc.channel}\e[0m"]
        end
      end

      module Users
        def self.last_callers_list(callers)
          return ['  (no callers recorded yet)'] if callers.empty?
          callers.map do |c|
            ts = c.timestamp.to_s[0, 19].sub('T', ' ')
            "  \e[2;37m#{ts}\e[0m  \e[1;33m#{c.username}\e[0m"
          end
        end
      end

      module Sysop
        def self.console_body(username:, online_count:, total_messages:,
                              chat_subscribers:, online_users:, recent_callers:)
          body = []
          body << "  Sysop: \e[1;33m#{username}\e[0m"
          body << :spacer
          body << '  Stats'
          body << "  · Online users:  #{online_count}"
          body << "  · Total messages: #{total_messages}"
          body << "  · Chat subscribers: #{chat_subscribers}"
          body << :spacer
          body << '  Online users:'
          online_users.each { |u| body << "  · #{u}" }
          body << :spacer
          body << '  Last 5 callers:'
          recent_callers.each do |c|
            body << "  · #{c.username}  #{c.timestamp[0, 16].sub('T', ' ')}"
          end
          body
        end
      end
    end
  end
end
