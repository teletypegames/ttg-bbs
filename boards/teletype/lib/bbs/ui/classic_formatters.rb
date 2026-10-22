# frozen_string_literal: true

require 'yaml'
require 'date'

# View helpers of the classic BBS parts: the logon and logoff screens,
# nodes, mail, the voting booth, file areas, bulletins and the hall of
# fame. Like formatters.rb: data and a width in, lines out.
module UI
  module Formatters
    Y = "\e[1;33m"
    C = "\e[1;36m"
    W = "\e[1;37m"
    D = "\e[0;37m"
    K = "\e[1;30m"
    G = "\e[1;32m"
    R = "\e[1;31m"
    M = "\e[1;35m"
    O = "\e[0m"

    def self.bar(value, max, width)
      filled = max.positive? ? (value.to_f / max * width).round : 0
      "#{C}#{'█' * filled}#{K}#{'░' * (width - filled)}#{O}"
    end

    def self.number(n) = n.to_i.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

    def self.duration(seconds)
      seconds = seconds.to_i
      return "#{seconds}s" if seconds < 60
      return "#{seconds / 60}m" if seconds < 3600

      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    end

    def self.wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, [width, 10].max)

    module Taglines
      PATH = File.expand_path('../../content/taglines.yml', __dir__)
      LIST = YAML.safe_load_file(PATH).freeze

      # A tagline or one of the team's mottos, [text, who].
      def self.pick(members)
        mottos = members.reject { |m| m.motto.to_s.strip.empty? }.map { |m| [m.motto, m.nick] }
        (LIST.map { |t| [t, nil] } + mottos).sample
      end

      # The quote of the day: the same for every caller until midnight.
      def self.of_the_day(members)
        mottos = members.reject { |m| m.motto.to_s.strip.empty? }.map { |m| [m.motto, m.nick] }
        pool   = mottos.empty? ? LIST.map { |t| [t, nil] } : mottos
        pool[Date.today.yday % pool.size]
      end

      def self.line(quote)
        text, who = quote
        "\"#{text}\"#{" — #{who}" if who}"
      end
    end

    module Logon
      MODEM = [
        ['ATZ', 0.25], ['OK', 0.2], ['ATDT TELETYPE', 0.5],
        ["#{K}~ ringing ~#{O}", 0.6], ["#{K}~ handshake: ≈≈≈ ∿∿∿ ≋≋≋ ~#{O}", 0.7],
        ["#{G}CONNECT 38400/ARQ/V42BIS#{O}", 0.4]
      ].freeze

      def self.connect(runner)
        runner.write "\e[0m\e[2J\e[H\r\n"
        MODEM.each do |text, wait|
          runner.write "  #{D}#{text}#{O}\r\n"
          sleep wait
        end
      end

      # The art of the logon matrix, cut to leave room for the prompt.
      def self.matrix(runner, art_lines, caller_number:, nodes:)
        rows = runner.session.term_rows || 24
        runner.write "\e[0m\e[2J\e[H"
        art_lines.first([rows - 4, 1].max).each { |l| runner.write "#{l}\e[0m\r\n" }
        runner.write "  #{C}Teletype BBS#{O} #{K}·#{O} #{D}telnet teletypegames.org:2323#{O} #{K}·#{O} " \
                     "#{D}caller ##{Formatters.number(caller_number)}#{O} #{K}·#{O} #{D}#{nodes} online#{O}\r\n"
      end

      def self.dots(label, width = 34) = "  #{D}#{label} #{K}#{'.' * [width - label.length, 2].max}#{O} "

      # The logon sequence after the name: who you are, then the scans.
      def self.screen(runner, name:, node:, caller_number:, stats:, registered:, mail:, new_scan:,
                      polls_open:, new_files:, quote:)
        out = ->(text) { runner.write(text) }
        out.call "\e[0m\e[2J\e[H\r\n"
        out.call "  #{C}═══#{O} #{W}Teletype BBS#{O} #{C}#{'═' * 47}#{O} #{W}Node #{node}#{O} #{C}═══#{O}\r\n" if node
        out.call "\r\n"
        greeting = stats ? "Welcome back, #{Y}#{name}#{O}!" : "Welcome, #{Y}#{name}#{O}! Your first call here."
        out.call "  #{W}#{greeting}#{O}   You are caller #{Y}##{Formatters.number(caller_number)}#{O}.\r\n"
        if stats
          last  = stats.last_call.localtime.strftime('%Y-%m-%d %H:%M')
          first = stats.first_call.localtime.strftime('%Y-%m-%d')
          out.call "  #{D}Calls: #{stats.calls} · last on #{last} · first on #{first} · " \
                   "online #{Formatters.duration(stats.seconds)}#{O}\r\n"
        end
        unless registered
          note = name == 'Anonymous' ? 'Call with a name to keep one.' : 'A guest: Users > Register keeps your name.'
          out.call "  #{D}#{note}#{O}\r\n"
        end
        out.call "\r\n"
        scan(out, 'Checking your mailbox') do
          if mail.nil? then "#{K}register to get mail#{O}"
          elsif mail.zero? then "#{D}no new letters#{O}"
          else "#{Y}#{mail} new letter#{'s' if mail != 1}#{O} #{D}(Messages > Mail)#{O}"
          end
        end
        scan(out, 'Scanning the message bases') do
          if new_scan.nil? then "#{K}register to keep track#{O}"
          elsif new_scan.empty? then "#{D}nothing new#{O}"
          else new_scan.map { |b, n| "#{Y}#{b.title}#{O} #{n} new" }.join(' · ')
          end
        end
        scan(out, 'Visiting the voting booth') do
          if polls_open.zero? then "#{D}you voted on every poll#{O}"
          else "#{Y}#{polls_open} poll#{'s' if polls_open != 1}#{O} #{D}wait for your vote#{O}"
          end
        end
        scan(out, 'Looking for new files') do
          new_files.empty? ? "#{D}no new files this month#{O}" : new_files.first(2).join(' · ')
        end
        out.call "\r\n  #{C}Quote of the day#{O}\r\n"
        Formatters.wrap(Taglines.line(quote), 72).each { |l| out.call "  #{W}#{l}#{O}\r\n" }
        out.call "\r\n  #{K}[#{O}#{Y}ENTER#{O}#{K}]#{O} #{D}to enter the board#{O} "
      end

      def self.scan(out, label)
        out.call dots(label)
        sleep 0.25
        out.call "#{yield}\r\n"
      end

      def self.goodbye(runner, name:, seconds:, caller_number:, quote:)
        out = ->(text) { runner.write(text) }
        out.call "\e[0m\e[2J\e[H\r\n"
        out.call "  #{C}╔══════════════════════════════════════════════════════════════╗#{O}\r\n"
        out.call "  #{C}║#{O}  #{W}Thanks for calling the Teletype BBS, #{Y}#{name[0, 20].ljust(20)}#{O}   #{C}║#{O}\r\n"
        out.call "  #{C}╚══════════════════════════════════════════════════════════════╝#{O}\r\n\r\n"
        out.call "  #{D}Caller ##{Formatters.number(caller_number)} · on line for #{Formatters.duration(seconds)}#{O}\r\n\r\n"
        Formatters.wrap(Taglines.line(quote), 70).each { |l| out.call "  #{K}...#{O}#{W}#{l}#{O}\r\n" }
        out.call "\r\n  #{D}Our games:#{O}              #{C}https://teletypegames.org#{O}\r\n"
        out.call "  #{D}The board in a browser:#{O} #{C}https://bbsweb.teletypegames.org#{O}\r\n\r\n"
        sleep 1.2
        out.call "  #{D}+++#{O}\r\n"
        sleep 0.6
        out.call "  #{D}ATH0#{O}\r\n"
        sleep 0.4
        out.call "  #{R}NO CARRIER#{O}\r\n\r\n"
      end
    end

    module Nodes
      def self.body(nodes, me)
        return ['  (no one on the lines)'] if nodes.empty?

        header = "  #{K}Node  User                  Doing                         On for#{O}"
        rows = nodes.map do |n|
          name = n.name.to_s[0, 20].ljust(21)
          mark = n.session_id == me ? "#{G}◄#{O}" : ' '
          "  #{Y}#{n.number.to_s.rjust(3)}#{O}   #{W}#{name}#{O} #{C}#{n.activity.to_s[0, 29].ljust(29)}#{O} " \
            "#{D}#{Formatters.duration(Time.now - n.since).rjust(6)}#{O} #{mark}"
        end
        [header, "  #{K}#{'─' * 66}#{O}", *rows]
      end
    end

    module UserList
      def self.body(rows)
        return ['  (nobody has registered yet)'] if rows.empty?

        header = "    #{K}User                 Calls  Last call         From#{O}"
        list = rows.map do |name, stats, location, online|
          last = stats ? stats.last_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'
          dot  = online ? "#{G}●#{O}" : ' '
          "  #{dot} #{W}#{name.to_s[0, 20].ljust(21)}#{O}#{Y}#{(stats&.calls || 0).to_s.rjust(5)}#{O}  " \
            "#{D}#{last.ljust(16)}#{O}  #{C}#{location.to_s[0, 18]}#{O}"
        end
        [header, "  #{K}#{'─' * 66}#{O}", *list, :spacer, "  #{G}●#{O} #{D}on line now#{O}"]
      end
    end

    module MyStats
      def self.body(name:, registered:, stats:, node:, caller_number:, posts:, ballots:, letters:, member_since:)
        rows = [
          ['Name',        registered ? "#{name} (registered)" : "#{name} (guest)"],
          ['This call',   "caller ##{Formatters.number(caller_number)}#{", node #{node.number}" if node}"],
          ['Calls',       stats ? stats.calls.to_s : 'this is your first'],
          ['First call',  stats ? stats.first_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'],
          ['Last call',   stats ? stats.last_call.localtime.strftime('%Y-%m-%d %H:%M') : '—'],
          ['Time online', stats ? Formatters.duration(stats.seconds) : '—'],
          ['Posts',       posts.to_s],
          ['Votes',       ballots.to_s],
          ['Mail',        letters.nil? ? 'register to get mail' : "#{letters} letter#{'s' if letters != 1}"]
        ]
        rows << ['Member since', member_since.to_s[0, 10]] if member_since
        [{ kv: rows, label_width: 14 }]
      end
    end

    module Mail
      def self.label(letter)
        mark = letter.read? ? ' ' : '•'
        "#{mark} #{letter.time.localtime.strftime('%m-%d')} #{letter.from.to_s[0, 12].ljust(12)} #{letter.subject}"
      end

      def self.detail(letter, width)
        [
          "  #{K}From:#{O}    #{Y}#{letter.from}#{O}",
          "  #{K}To:#{O}      #{W}#{letter.to}#{O}",
          "  #{K}Date:#{O}    #{D}#{letter.time.localtime.strftime('%Y-%m-%d %H:%M')}#{O}",
          "  #{K}Subject:#{O} #{C}#{letter.subject}#{O}",
          "  #{K}#{'─' * [width - 5, 1].max}#{O}",
          *letter.body.to_s.split("\n").flat_map { |l|
            if l.strip.empty?
              ['']
            else
              Formatters.wrap(l, width - 4).map { |w|
                "  #{w}"
              }
            end
          }
        ]
      end

      def self.empty(registered)
        registered ? '  (your mailbox is empty)' : '  (register your name to get mail — Users > Register…)'
      end
    end

    module Voting
      def self.label(poll, voted)
        "#{voted ? '✓' : '•'} #{poll.title}"
      end

      def self.detail(poll, results, total, ballot, width)
        max   = results.map(&:last).max || 0
        bar_w = width < 60 ? 10 : 20
        opt_w = (width - 16 - bar_w).clamp(12, 28)
        lines = Formatters.wrap(poll.question, width - 4).map { |l| "  #{W}#{l}#{O}" }
        lines << "  #{D}#{total} vote#{'s' if total != 1}#{ballot ? " · yours: #{ballot}" : ' · you have not voted yet'}#{O}"
        lines << ''
        results.each_with_index do |(option, votes), i|
          pct  = total.positive? ? (votes * 100.0 / total).round : 0
          mine = option == ballot ? "#{G}◄#{O}" : ' '
          lines << "  #{Y}#{(i + 1).to_s.rjust(2)}.#{O} #{option.to_s[0, opt_w].ljust(opt_w)} " \
                   "#{Formatters.bar(votes, max, bar_w)} #{W}#{pct.to_s.rjust(3)}%#{O} #{mine}"
        end
        lines << ''
        lines << "  #{D}Enter or Vote, then the number of your choice.#{O}"
        lines
      end
    end

    module FileAreas
      KINDS = {
        'win_x64' => 'Windows', 'win_x86' => 'Windows 32-bit', 'linux_x64' => 'Linux', 'linux_arm64' => 'Linux ARM',
        'mac_x64' => 'macOS Intel', 'mac_arm64' => 'macOS ARM', 'mac_universal' => 'macOS',
        'html' => 'web build', 'cartridge' => 'cartridge', 'source' => 'source', 'docs' => 'docs',
        'prg' => 'C64/264 program'
      }.freeze

      def self.area_label(area)
        "#{area.title.ljust(18)} #{area.files.size.to_s.rjust(3)} files"
      end

      def self.area_detail(area, width)
        newest = area.files.map(&:date).compact.max
        games  = area.files.map(&:game).uniq
        lines  = ["  #{Y}#{area.title}#{O}",
                  "  #{D}#{games.size} title#{'s' if games.size != 1} · #{area.files.size} files · " \
                  "#{Ftp.size(area.files.sum(&:bytes))}#{O}"]
        lines << "  #{D}newest: #{newest.strftime('%Y-%m-%d')}#{O}" if newest
        lines << ''
        games.each do |g|
          lines << "  #{W}#{g.title}#{O} #{D}#{g.version}#{O}"
          Formatters.wrap(g.desc, width - 6).first(2).each { |l| lines << "    #{D}#{l}#{O}" }
        end
        lines << ''
        lines << "  #{K}Enter opens the area.#{O}"
        lines
      end

      def self.file_label(item, service)
        flag = service.new?(item) ? '*' : ' '
        name = item.name.length > 24 ? "#{item.name[0, 23]}…" : item.name
        "#{flag}#{name.ljust(24)} #{size(item.bytes).rjust(7)}"
      end

      # At most seven characters, for the file list's column.
      def self.size(bytes)
        return "#{bytes} B" if bytes < 1024
        return format(bytes < 100 * 1024 ? '%.1f KB' : '%.0f KB', bytes / 1024.0) if bytes < 1024 * 1024

        format('%.1f MB', bytes / 1024.0 / 1024)
      end

      # The file's FILE_ID.DIZ: a 44-column box, the way uploaders made them.
      def self.diz(item, inner = 42)
        g = item.game
        body = [g.title.center(inner), "v#{g.version} · #{GamesService.platform_name(g.platform)}".center(inner),
                '-' * inner]
        body.concat(Formatters.wrap(g.desc, inner).first(5))
        body << ''
        body << "#{KINDS.fetch(item.kind, item.kind)} · #{g.license.empty? ? 'free' : g.license}".center(inner)
        body << '(c) Teletype Games'.center(inner)
        ["#{C}┌#{'─' * inner}┐#{O}",
         *body.map { |l| "#{C}│#{O}#{W}#{BBS::FrameBuffer.clip_ansi(l, inner).ljust(inner)}#{O}#{C}│#{O}" },
         "#{C}└#{'─' * inner}┘#{O}"]
      end

      def self.file_detail(item, width, files:, catalog_url:)
        rows = [['File', item.name], ['Size', Ftp.size(item.bytes)],
                ['Date', item.date&.strftime('%Y-%m-%d').to_s], ['Kind', KINDS.fetch(item.kind, item.kind)],
                ['DLs', "#{item.downloads} (#{item.game.downloads} all versions)"]]
        lines = rows.map { |k, v| "  #{K}#{k.ljust(5)}#{O} #{v}" }
        lines << ''
        lines.concat(diz(item, (width - 6).clamp(20, 42)).map { |l| "  #{l}" })
        lines << ''
        lines << "  #{C}#{catalog_url}#{O}"
        lines << "  #{C}#{files.url(item.path)}#{O}"
        lines << ''
        how = if files.downloadable?(FtpEntry.new(bytes: item.bytes, dir: false))
                'Enter or Download sends it to your terminal by ZMODEM.'
              else
                'Too big for ZMODEM from here: fetch it from the addresses above.'
              end
        Formatters.wrap(how, width - 4).each { |l| lines << "  #{D}#{l}#{O}" }
        lines
      end
    end

    module History
      # The story of the collective in releases, by month, newest first.
      def self.lines(history, width)
        return ['  (the catalog did not answer — try again later)'] if history.empty?

        first = history.last[1].released_at
        lines = ["  #{W}#{history.size} releases of #{history.map { |g, _| g.name }.uniq.size} titles " \
                 "since #{first.strftime('%B %Y')}#{O}", '']
        history.group_by { |_, r| r.released_at.strftime('%Y-%m') }.each do |month, rel|
          lines << "  #{Y}#{Time.strptime(month, '%Y-%m').strftime('%B %Y')}#{O} #{K}#{'─' * [width - 22, 4].max}#{O}"
          rel.each do |g, r|
            day = r.released_at.strftime('%d')
            lines << "    #{D}#{day}#{O}  #{K}#{g.platform.ljust(10)}#{O} #{W}#{g.title}#{O} #{C}#{r.version}#{O}"
          end
          lines << ''
        end
        lines
      end
    end

    module HallOfFame
      def self.section(title, rows, width, unit)
        lines = ["  #{Y}#{title}#{O}", "  #{K}#{'─' * [width - 5, 10].max}#{O}"]
        if rows.empty?
          lines << "  #{D}(nobody yet)#{O}"
        else
          max   = rows.map(&:last).max
          bar_w = [width - 42, 6].max
          rows.each_with_index do |(name, n), i|
            lines << "  #{W}#{(i + 1).to_s.rjust(2)}.#{O} #{name.to_s[0, 22].ljust(22)} #{Formatters.bar(n, max, bar_w)} " \
                     "#{Y}#{n.to_s.rjust(5)}#{O} #{D}#{unit}#{O}"
          end
        end
        lines + ['']
      end

      def self.body(downloads:, callers:, posters:, trivia:, width:)
        section('Most downloaded games', downloads, width, 'DLs') +
          section('Top callers', callers, width, 'calls') +
          section('Top posters', posters, width, 'posts') +
          section('TTG Trivia high scores', trivia, width, 'pts')
      end
    end

    module Bulletins
      LIST = [
        { label: ' 1  The logon bulletin',      kind: :logon },
        { label: ' 2  About Teletype Games',    kind: :about },
        { label: ' 3  The story so far',        kind: :history },
        { label: ' 4  Coming up',               kind: :events },
        { label: ' 5  Board rules',             kind: :file, file: 'rules.md' },
        { label: ' 6  New to BBSes?',           kind: :file, file: 'newcomers.md' },
        { label: ' 7  Our BBS network',         kind: :network }
      ].freeze
    end

    module PageSysop
      def self.text(sysop_online)
        if sysop_online
          'The sysop is on line and heard the bell: look for an answer in Live Chat (F4).'
        else
          'The sysop is not at the keyboard. The page went to the team, but the surest way is a letter: ' \
            'leave one now?'
        end
      end
    end
  end
end
