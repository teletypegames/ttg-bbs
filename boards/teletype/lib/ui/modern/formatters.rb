# frozen_string_literal: true

require_relative '../../domain/model/ftp_models'

# Pure view-layer helpers used by the window DSL in lib/ui/modern.rb. No business
# logic here — each method takes data + width and returns lines/strings.
module UI
  module Modern
    module Formatters
      module Bulletin
        BANNER = Logo.half_blocks.map { |l| "  #{l}" }.freeze

        def self.body(username:, registered:, online_count:, total_messages:,
                      recent_callers:, releases:, events:, oneliners:)
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
            "What's new:",
            *(releases.empty? ? ['  (no releases)'] : releases.map { |g| News.release_line(g) }),
            :spacer,
            'Coming up:',
            *(events.empty? ? ['  (nothing scheduled)'] : events.map { |e| News.event_line(e) }),
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

      module Ftp
        UP = FtpEntry.new(name: '..', dir: true, bytes: 0).freeze

        def self.size(bytes)
          return "#{bytes} B" if bytes < 1024
          return format('%.1f KB', bytes / 1024.0) if bytes < 1024 * 1024

          format('%.1f MB', bytes / 1024.0 / 1024)
        end

        def self.title(host, path) = " FTP — #{host}#{path} "

        def self.items(path, entries)
          return [] if entries.nil?

          up = path == FileLibraryService::ROOT ? [] : [UP.dup.tap { |e| e.path = File.dirname(path) }]
          up + entries
        end

        def self.label(entry)
          return "\u25B8 #{entry.name}/" if entry.dir

          name = entry.name.length > 26 ? "#{entry.name[0, 25]}…" : entry.name
          "  #{name.ljust(26)} #{size(entry.bytes).rjust(9)}"
        end

        def self.date(entry) = entry.modified&.strftime('%Y-%m-%d %H:%M').to_s

        def self.detail(entry, width, files:, theme:)
          return folder(entry, files) if entry.dir

          lines = ["  \e[1;33m#{entry.name}\e[0m",
                   "  \e[0;37m#{size(entry.bytes)} (#{entry.bytes} bytes) · #{date(entry)}\e[0m", '',
                   "  \e[1;36m#{files.url(entry.path)}\e[0m"]
          https = files.https_url(entry.path)
          lines << "  \e[1;36m#{https}\e[0m" if https
          lines << ''
          how = if files.downloadable?(entry)
                  'Enter or Download sends it to your terminal by ZMODEM (SyncTERM, NetRunner, ' \
                    'Qodem, rz, or the web terminal). Or fetch it with any FTP client from the address above.'
                else
                  "Too big for a ZMODEM download from here (over #{size(FileLibraryService::DOWNLOAD_MAX)}): " \
                    'fetch it with an FTP client from the address above.'
                end
          BBS::FrameBuffer.wrap_ansi(how, width - 4).each { |l| lines << "  #{l}" }
          if files.preview?(entry)
            text = files.preview(entry)
            unless text.strip.empty?
              lines << ''
              lines << "  \e[2;37m#{'─' * [width - 5, 1].max}\e[0m"
              lines.concat(preview_lines(entry, text, width, theme))
            end
          end
          lines
        end

        def self.preview_lines(entry, text, width, theme)
          return BBS::Markdown.to_lines(text, width: width - 1, theme: theme) if entry.name.match?(/\.md\z/i)

          text.delete("\r").split("\n").flat_map do |line|
            line = line.gsub("\t", '    ').gsub(/[\x00-\x1f\x7f]/, '')
            line.empty? ? [''] : BBS::FrameBuffer.wrap_ansi(line, width - 4).map { |l| "  #{l}" }
          end
        end

        def self.folder(entry, files)
          path = entry.path || '/'
          ["  \e[1;33m#{entry.name == '..' ? '.. (up)' : "#{entry.name}/"}\e[0m",
           "  \e[0;37m#{path}\e[0m", '', "  \e[1;36m#{files.url(path)}\e[0m", '',
           '  Enter opens it.']
        end

        def self.meta(entry, files)
          files.downloadable?(entry) ? "Enter: download #{entry.name} by ZMODEM" : "#{size(entry.bytes)}: FTP client only"
        end

        def self.offer(entry)
          "Send #{entry.name} (#{size(entry.bytes)}) to your terminal by ZMODEM? " \
            'Most BBS terminals start receiving by themselves; with rz, start it by hand. Esc cancels the wait.'
        end

        def self.too_big(entry, files)
          ["#{entry.name} is #{size(entry.bytes)}: too big to send from the BBS. Fetch it with an FTP client:",
           files.url(entry.path), files.https_url(entry.path)].compact.join(' ')
        end

        def self.fetching(entry) = "\r\n  Fetching #{entry.name} from the FTP server...\r\n"

        def self.sending(entry)
          "  Sending #{entry.name} by ZMODEM. Start receiving if your terminal does not; Esc gives up.\r\n\r\n"
        end

        def self.result(result, entry, files)
          case result
          when :ok         then "#{entry.name} sent."
          when :cancelled  then 'Download cancelled.'
          when :timeout
            "Your terminal did not answer in ZMODEM. Fetch #{entry.name} by FTP instead: #{files.url(entry.path)}"
          when :unreadable then 'The FTP server did not hand over the file. Try again later.'
          else 'The download stopped.'
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

        QUICK_QUESTIONS = [
          ['&What is new?',                   'What is new? What was released lately?'],
          ['What is &coming up?',             'What events are coming up?'],
          ['&Where do I start?',              'I am new here. Where do I start?'],
          ['How do I &download files?',       'How do I download files from the FTP server?'],
          ['Which &doors are there?',         'Which doors are there?']
        ].freeze

        # One speaker's turn, wrapped to the Stream window (cols - 8 wide, a
        # border and a scrollbar inside).
        def self.lines(who, text, cols, you: false)
          color = you ? "\e[1;36m" : "\e[1;33m"
          width = [cols - 14, 20].max
          BBS::FrameBuffer.wrap_ansi("#{color}#{who}\e[0m: #{text}", width).map { |l| "  #{l}" } + ['']
        end
      end

      module Gallery
        def self.detail(name, sauce, size, preview, width)
          meta = [['File', name], ['Size', Ftp.size(size)]]
          if sauce
            meta << ['Title', sauce.title] unless sauce.title.empty?
            meta << ['Artist', sauce.author] unless sauce.author.empty?
            meta << ['Group', sauce.group] unless sauce.group.empty?
            meta << ['Date', sauce.date] unless sauce.date.empty?
          end
          [*meta.map { |k, v| "  \e[0;37m#{k.ljust(7)}\e[0m #{v}" }, '',
           *preview.map { |l| BBS::FrameBuffer.clip_ansi(l, width) }]
        end
      end

      module News
        def self.release_line(game)
          date = game.released_at&.strftime('%Y-%m-%d')
          "  · \e[1;33m#{game.title}\e[0m #{game.version}  \e[2;37m#{game.platform} · #{date}\e[0m"
        end

        def self.event_line(event)
          "  · #{event.date.strftime('%Y-%m-%d')}  #{event.name}"
        end

        def self.body(releases:, events:, posts:, catalog_url:)
          body = ['  Latest releases']
          if releases.empty?
            body << '  (no releases)'
          else
            releases.each do |g|
              body << release_line(g)
              body << "    \e[1;36m#{catalog_url.call(g)}\e[0m"
            end
          end
          body << :spacer
          body << '  Upcoming events'
          body.concat(events.empty? ? ['  (nothing scheduled)'] : events.map { |e| event_line(e) })
          body << :spacer
          body << '  From the blog (TTG Blog BBS, port 2328)'
          if posts.empty?
            body << '  (no posts yet — they will show up here and on teletypegames.org/blog)'
          else
            posts.each do |p|
              body << "  · #{p.created_at.localtime.strftime('%Y-%m-%d')}  \e[1;33m#{p.title}\e[0m" \
                      "#{"  \e[2;37m#{p.author}\e[0m" if p.author}"
              body << "    \e[1;36m#{p.url}\e[0m"
            end
          end
          body
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
        SYSTEMS = TeletypeBBS::NETWORK

        def self.body
          rows = SYSTEMS.flat_map do |name, address, note|
            ["  \e[1;33m#{name.ljust(14)}\e[0m \e[1;36m#{address}\e[0m", "  #{' ' * 15}#{note}"]
          end
          [*rows, :spacer, '  What each door here is: Doors > Door Lobby.',
           :spacer, '  In a browser, no telnet client needed:',
           "  \e[1;36mhttps://bbsweb.teletypegames.org\e[0m"]
        end
      end

      module Dos
        FTP_INTRO = <<~MD
          # The DOS corner

          Our DOS programs live on the FTP server, and they install each other.

          - **Server:** `ftp.teletypegames.org`, port 21, anonymous, read-only, passive mode
          - **/APPS** — DOS programs (GMENU, DOSINST, BMAGIC, TTGWIKI…)
          - **/WIKI** — this wiki exported for DOS, read by TTGWIKI
          - **/WARP** — every game file of the teletypegames.org catalog

          Start with **DOSINST**: it installs, updates and removes the others
          over the network (mTCP, packet driver). The pages on the left tell
          each program's story.
        MD
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

      module Game
        LABEL_TITLE = 21

        # The title first, the platform after it, each in its own column.
        def self.label(game)
          title = game.title.length > LABEL_TITLE ? "#{game.title[0, LABEL_TITLE - 1]}…" : game.title
          "#{title.ljust(LABEL_TITLE)} #{game.platform[0, 10]}"
        end

        # A long address cut at the width, the rest on the next lines.
        def self.url_lines(url, width, indent = '  ')
          url.to_s.scan(/.{1,#{[width - indent.length, 10].max}}/).map { |part| "#{indent}\e[1;36m#{part}\e[0m" }
        end

        def self.card(game, width, catalog_url:)
          wrap  = ->(text, w = width - 4) { BBS::FrameBuffer.wrap_ansi(text.to_s, w) }
          lines = wrap.call(game.title).map { |l| "  \e[1;33m#{l}\e[0m" }
          meta = [game.platform, game.category, game.author].reject(&:empty?).join(' · ')
          wrap.call(meta).each { |l| lines << "  \e[0;36m#{l}\e[0m" }
          if game.released?
            date = game.released_at&.strftime('%Y-%m-%d')
            lines << "  \e[0;37mLatest: #{game.version}#{"  (#{date})" if date}\e[0m"
          end
          facts = [(game.status.empty? ? nil : game.status), (game.license.empty? ? nil : game.license),
                   "#{game.downloads} downloads"].compact.join(' · ')
          wrap.call(facts).each { |l| lines << "  \e[0;37m#{l}\e[0m" }
          lines.concat(url_lines(catalog_url.to_s.delete_prefix('https://'), width - 2))
          lines << ''
          BBS::FrameBuffer.wrap_ansi(game.desc.to_s, width - 4).each { |l| lines << "  #{l}" }
          unless game.story.to_s.strip.empty?
            lines << ''
            BBS::FrameBuffer.wrap_ansi(game.story.to_s, width - 4).each { |l| lines << "  #{l}" }
          end
          unless game.assets.empty?
            lines << ''
            wrap.call('Downloads, on the catalog page above:').each { |l| lines << "  #{l}" }
            kinds = game.assets.map(&:kind).join(' · ')
            BBS::FrameBuffer.wrap_ansi(kinds, width - 6).each { |l| lines << "    \e[0;37m#{l}\e[0m" }
          end
          if game.releases.size > 1
            lines << ''
            lines << '  Release history:'
            game.releases.reverse_each do |r|
              lines << "    \e[1;33m#{r.version.ljust(16)}\e[0m \e[0;37m#{r.released_at&.strftime('%Y-%m-%d')}  " \
                       "#{r.downloads} DLs\e[0m"
            end
          end
          unless game.external_links.empty?
            lines << ''
            game.external_links.each do |link|
              lines << "  \e[0;37m#{link[:label]}\e[0m"
              lines.concat(url_lines(link[:url], width - 2, '    '))
            end
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

        def self.title(irc) = " IRC — #{irc.channel} on #{NETWORK} "

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
