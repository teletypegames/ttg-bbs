# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/online_users'
require_relative 'lib/message_board'
require_relative 'lib/wiki'
require_relative 'lib/catalog'

ONLINE   = OnlineUsers.new
MESSAGES = MessageBoard.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiClient.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogClient.new

module C
  RESET   = "\e[0m"
  GRAY    = "\e[0;37m"
  YELLOW  = "\e[0;33m"
  WHITE   = "\e[1;37m"
  BLUE    = "\e[0;34m"
  CYAN    = "\e[0;36m"
  GREEN   = "\e[1;32m"
  MAGENTA = "\e[0;35m"
  RED     = "\e[1;31m"
end

def fmt_date(iso)
  Time.parse(iso.to_s).strftime('%Y-%m-%d')
rescue
  iso.to_s
end

def wrap_text(text, width: 60, indent: 4)
  clean = text.to_s
              .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
              .gsub(/[#*_`~>|\\]/, '')
              .gsub(/\r?\n+/, ' ')
              .strip
  lines, line = [], +''
  clean.split.each do |word|
    if line.empty? then line << word
    elsif line.length + 1 + word.length <= width then line << ' ' << word
    else lines << line.dup; line = +word
    end
  end
  lines << line unless line.empty?
  lines.map { |l| "#{' ' * indent}#{l}\r\n" }.join
end

BBS.configure do |c|
  c.on_session_end = ->(session) { ONLINE.remove(session.session_id) }

  c.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success

    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(v) { v.strip.empty? ? 'Anonymous' : v.strip[0...20] }

    call { |ctx| ONLINE.add(ctx[:session_id], ctx[:username]) }

    menu 'Choice', loop: true do
      option 'Message Board' do
        section 'Message Board', color: :cyan
        rows(empty: 'No messages yet.') do |ctx|
          MESSAGES.last(30).map.with_index(1) do |msg, i|
            "#{C::GRAY}[#{i}]#{C::RESET} #{C::YELLOW}#{msg.timestamp}#{C::RESET} " \
            "#{C::WHITE}#{msg.username}#{C::RESET}: #{C::GRAY}#{msg.text}#{C::RESET}"
          end
        end
        wait_enter
      end

      option 'New Message' do
        ask :message_text, prompt: 'Message (max 200 chars)', validate: :non_empty
        call { |ctx| MESSAGES.append(ctx[:username], ctx[:message_text][0...200]) }
        say 'Sent.', style: :success
      end

      option 'Blog Posts' do
        section 'Blog Posts', color: :blue
        fetch :pages, loading: 'Loading...' do |ctx|
          WIKI.list('blog')
        end
        pick from: :pages,
             empty: 'No results.',
             prompt: 'Enter number to read (blank to go back)',
             item:  ->(p, i) { "#{C::GRAY}#{i}.#{C::RESET} #{C::BLUE}#{p['title']}#{C::RESET}  #{C::GRAY}#{fmt_date(p['createdAt'])}#{C::RESET}" },
             hint:  ->(p, i) { p['description'].to_s.strip[0...65] } do
          fetch :page_body, loading: 'Loading page...' do |ctx|
            WIKI.content(ctx[:picked]['id'])
          end
          line color: :blue
          text(style: :white) { |ctx| ctx[:picked]['title'] }
          text(style: :muted) { |ctx| "#{fmt_date(ctx[:picked]['createdAt'])}  #{WIKI.page_url(ctx[:picked]['locale'], ctx[:picked]['path'])}" }
          line color: :blue
          body { |ctx| ctx[:page_body] }
          wait_enter
        end
      end

      option 'HowTo Guides' do
        section 'HowTo Guides', color: :magenta
        fetch :pages, loading: 'Loading...' do |ctx|
          WIKI.list('howto')
        end
        pick from: :pages,
             empty: 'No results.',
             prompt: 'Enter number to read (blank to go back)',
             item:  ->(p, i) { "#{C::GRAY}#{i}.#{C::RESET} #{C::MAGENTA}#{p['title']}#{C::RESET}  #{C::GRAY}#{fmt_date(p['createdAt'])}#{C::RESET}" },
             hint:  ->(p, i) { p['description'].to_s.strip[0...65] } do
          fetch :page_body, loading: 'Loading page...' do |ctx|
            WIKI.content(ctx[:picked]['id'])
          end
          line color: :magenta
          text(style: :white) { |ctx| ctx[:picked]['title'] }
          text(style: :muted) { |ctx| "#{fmt_date(ctx[:picked]['createdAt'])}  #{WIKI.page_url(ctx[:picked]['locale'], ctx[:picked]['path'])}" }
          line color: :magenta
          body { |ctx| ctx[:page_body] }
          wait_enter
        end
      end

      option 'Game Catalog' do
        section 'Game Catalog', color: :cyan
        fetch :games, loading: 'Loading...' do |ctx|
          CATALOG.fetch
        end
        output do |ctx|
          games = Array(ctx[:games])
          next "  #{C::RED}Could not load catalog.#{C::RESET}\r\n\r\n" unless games.any?

          out = +''
          games.each_with_index do |entry, i|
            next unless entry.is_a?(Hash)
            sw     = entry['software']      || {}
            latest = entry['latestRelease'] || {}
            count  = (entry['releases']     || []).length
            desc   = sw['desc'].to_s.strip

            out << "\r\n  #{C::GRAY}#{'─' * 66}#{C::RESET}\r\n"
            out << "  #{C::CYAN}#{i + 1}. #{sw['title']}#{C::RESET}  " \
                   "#{C::GRAY}#{sw['platform']}  #{sw['author']}#{C::RESET}\r\n"
            out << wrap_text(desc) unless desc.empty?

            badges = []
            badges << "#{C::GREEN}[▶ Play]#{C::RESET}"      if latest['htmlFolderPath'].to_s != ''
            badges << "#{C::YELLOW}[⬇ Download]#{C::RESET}" if latest['cartridgePath'].to_s  != ''
            badges << "#{C::BLUE}[Source]#{C::RESET}"        if latest['sourcePath'].to_s     != ''
            badges << "#{C::MAGENTA}[Docs]#{C::RESET}"       if latest['docsFolderPath'].to_s != ''
            out << "  #{badges.join('  ')}\r\n" unless badges.empty?
            out << "  #{C::GRAY}#{CATALOG.play_url(latest['htmlFolderPath'])}#{C::RESET}\r\n" if latest['htmlFolderPath'].to_s != ''
            out << "  #{C::GRAY}#{count} versions available#{C::RESET}\r\n" if count > 1
          end

          out << "\r\n  #{C::GRAY}#{'─' * 66}#{C::RESET}\r\n"
          out << "  #{C::GRAY}#{CatalogClient::GAMES_URL}#{C::RESET}\r\n\r\n"
          out
        end
        wait_enter
      end

      option 'Online Users' do
        section 'Online Users', color: :yellow
        rows do |ctx|
          ONLINE.snapshot.sort.map do |sid, name|
            marker = sid == ctx[:session_id] ? "  #{C::GRAY}← you#{C::RESET}" : ''
            "#{C::WHITE}#{name}#{C::RESET}#{marker}"
          end
        end
        text(style: :muted) { |ctx| "#{ONLINE.count} user(s) online" }
        wait_enter
      end

      option 'System Info' do
        section 'System Info', color: :magenta
        table do |ctx|
          {
            'Online users' => ONLINE.count,
            'Messages'     => MESSAGES.count,
            'Wiki'         => 'https://wiki.teletype.hu',
            'Games API'    => 'https://games.teletype.hu',
            'Platform'     => RUBY_PLATFORM,
            'Ruby'         => RUBY_VERSION
          }
        end
        wait_enter
      end

      option 'Exit' do
        exit_menu
      end
    end

    say 'Goodbye!', style: :muted
  end
end

BBS.start
