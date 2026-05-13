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

      def self.body(username:, online_count:, total_messages:, recent_callers:)
        callers = recent_callers.map do |c|
          "  · #{c.username}  \e[2;37m#{c.timestamp[0, 16].sub('T', ' ')}\e[0m"
        end
        [
          *BANNER.map { |l| { text: l, style: :accent } },
          :spacer,
          "Logged in as \e[1;33m#{username}\e[0m",
          :spacer,
          "Online now:     #{online_count}",
          "Total messages: #{total_messages}",
          :spacer,
          'Last callers:',
          *callers
        ]
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
      def self.card(game, width)
        lines = []
        lines << "  \e[1;33m#{game.title}\e[0m"
        lines << "  \e[0;36m#{game.platform} · #{game.author}\e[0m"
        lines << ''
        BBS::FrameBuffer.wrap_ansi(game.desc.to_s,  width - 4).each { |l| lines << "  #{l}" }
        lines << ''
        BBS::FrameBuffer.wrap_ansi(game.story.to_s, width - 4).each { |l| lines << "  #{l}" }
        lines << ''
        game.external_links.each do |link|
          lines << "  \e[0;37m#{link[:label].ljust(10)}\e[0m \e[1;36m#{link[:url]}\e[0m"
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
