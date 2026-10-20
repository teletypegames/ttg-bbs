# frozen_string_literal: true

# Pure view-layer helpers used by the window DSL in bbs.rb. No business
# logic here — each method takes data + width and returns lines/strings.
module UI
  module Formatters
    module Bulletin
      BANNER = [
        "  \e[1;33m _____       _      _                  ____  ____  _____\e[0m",
        "  \e[1;33m|_   _|__   | |    | |_  __ _ _ _ ___  | __ )| __ )/ ____|\e[0m",
        "  \e[1;33m  | |/ _ \\  | |    | __|/ _` | '_/ _ \\ |  _ \\|  _ \\\\___ \\\e[0m",
        "  \e[1;33m  | |  __/  | |___ | |_| (_| | ||  __/ | |_) | |_) |___) |\e[0m",
        "  \e[1;33m  |_|\\___|  |_____|\\__|\\__,_|_| \\___| |____/|____/|____/\e[0m"
      ].freeze

      def self.body(username:, registered:, online_count:, total_messages:,
                    recent_callers:, releases:, events:)
        callers = recent_callers.map do |c|
          "  · #{c.username}  \e[2;37m#{c.timestamp[0, 16].sub('T', ' ')}\e[0m"
        end
        status = if registered then ''
                 elsif username == 'Anonymous' then "  \e[2;37m(call with a name to register it)\e[0m"
                 else "  \e[2;37m(guest — Users > Register keeps your name)\e[0m"
                 end
        [
          *BANNER.map { |l| { text: l, style: :accent } },
          :spacer,
          "Logged in as \e[1;33m#{username}\e[0m#{status}",
          "Online now: #{online_count}   Messages: #{total_messages}",
          :spacer,
          "What's new:",
          *(releases.empty? ? ['  (no releases)'] : releases.map { |g| News.release_line(g) }),
          :spacer,
          'Coming up:',
          *(events.empty? ? ['  (nothing scheduled)'] : events.map { |e| News.event_line(e) }),
          :spacer,
          'Last callers:',
          *(callers.empty? ? ['  (none yet)'] : callers)
        ]
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

      def self.body(releases:, events:, posts:, catalog_url:, post_url:)
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
        body << '  Blog'
        if posts.empty?
          body << '  (no posts yet — they will show up here and on teletypegames.org/blog)'
        else
          posts.first(5).each do |p|
            body << "  · #{p.created_at.to_s[0, 10]}  #{p.title}"
            body << "    \e[1;36m#{post_url.call(p)}\e[0m"
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

    module Network
      SYSTEMS = [
        ['Teletype BBS', 'teletypegames.org:2323', 'this board: messages, chat, news, catalog'],
        ['Impostor BBS', 'teletypegames.org:2324', 'post-game terminal of Definitely not an Impostor'],
        ['WIKI-BBS',     'teletypegames.org:2325', 'the whole wiki in a two-pane browser'],
        ['SERMO',        'teletypegames.org:2326', 'a Neumatronic Margittai machine — talk to it']
      ].freeze

      def self.body
        rows = SYSTEMS.flat_map do |name, address, note|
          ["  \e[1;33m#{name.ljust(14)}\e[0m \e[1;36m#{address}\e[0m", "  #{' ' * 15}#{note}"]
        end
        [*rows, :spacer, '  In a browser, no telnet client needed:',
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

    module Board
      def self.lines(messages, board_title, width)
        return ["  (no messages on #{board_title} yet — press 'n' to start one)"] if messages.empty?
        lines = []
        messages.each do |m|
          head = "\e[2;37m#{m.timestamp}\e[0m  \e[1;33m#{m.username}\e[0m: "
          BBS::FrameBuffer.wrap_ansi(head + m.text.to_s, width - 1).each { |l| lines << l }
          lines << ''
        end
        lines
      end
    end

    module Game
      def self.label(game)
        "#{game.platform.ljust(10)} #{game.title}"
      end

      def self.card(game, width, catalog_url:)
        lines = []
        lines << "  \e[1;33m#{game.title}\e[0m"
        meta = [game.platform, game.category, game.author].reject(&:empty?).join(' · ')
        lines << "  \e[0;36m#{meta}\e[0m"
        if game.released?
          date = game.released_at&.strftime('%Y-%m-%d')
          lines << "  \e[0;37mLatest: #{game.version}#{date ? "  (#{date})" : ''}\e[0m"
        end
        lines << "  \e[1;36m#{catalog_url}\e[0m"
        lines << ''
        BBS::FrameBuffer.wrap_ansi(game.desc.to_s,  width - 4).each { |l| lines << "  #{l}" }
        unless game.story.to_s.strip.empty?
          lines << ''
          BBS::FrameBuffer.wrap_ansi(game.story.to_s, width - 4).each { |l| lines << "  #{l}" }
        end
        unless game.assets.empty?
          lines << ''
          lines << '  Downloads (on the catalog page above):'
          kinds = game.assets.map(&:kind).join(' · ')
          BBS::FrameBuffer.wrap_ansi(kinds, width - 6).each { |l| lines << "    \e[0;37m#{l}\e[0m" }
        end
        unless game.external_links.empty?
          lines << ''
          game.external_links.each do |link|
            lines << "  \e[0;37m#{link[:label]}\e[0m"
            lines << "    \e[1;36m#{link[:url]}\e[0m"
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

    module Users
      def self.online_list(usernames, current_user)
        return ['  (no one else here yet)'] if usernames.empty?
        usernames.map { |u| u == current_user ? "  #{u}  ← you" : "  #{u}" }
      end

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
