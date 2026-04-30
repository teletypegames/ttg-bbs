# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'

ONLINE   = OnlineUsersRepository.new
MESSAGES = MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogRepository.new

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

def c(color, text)
  "#{C.const_get(color.to_s.upcase)}#{text}#{C::RESET}"
end

class OutputBuilder
  def initialize = (@buf = +''; @badges = [])
  def to_s       = (flush_badges; @buf)

  def sep(color = :gray)
    flush_badges
    @buf << "\r\n  #{c(color, '─' * 66)}\r\n"
  end

  def line(text, color = nil)
    flush_badges
    @buf << "  #{color ? c(color, text) : text}\r\n"
  end

  def cols(**pairs)
    flush_badges
    @buf << "  #{pairs.map { |color, text| c(color, text.to_s) }.join('  ')}\r\n"
  end

  def para(text)
    flush_badges
    @buf << wrap_text(text) unless text.to_s.strip.empty?
  end

  def badge(color, text)
    @badges << c(color, text)
  end

  private

  def c(color, text) = "#{C.const_get(color.to_s.upcase)}#{text}#{C::RESET}"

  def flush_badges
    return if @badges.empty?
    @buf << "  #{@badges.join('  ')}\r\n"
    @badges = []
  end
end

def render(&block)
  OutputBuilder.new.tap { |b| b.instance_eval(&block) }.to_s
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
            "#{c(:gray, "[#{i}]")} #{c(:yellow, msg.timestamp)} #{c(:white, msg.username)}: #{c(:gray, msg.text)}"
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
             item:  ->(p, i) { "#{c(:gray, "#{i}.")} #{c(:blue, p.title)}  #{c(:gray, fmt_date(p.created_at))}" },
             hint:  ->(p, i) { p.description.to_s.strip[0...65] } do
          fetch :page_body, loading: 'Loading page...' do |ctx|
            WIKI.content(ctx[:picked].id)
          end
          line color: :blue
          text(style: :white) { |ctx| ctx[:picked].title }
          text(style: :muted) { |ctx| "#{fmt_date(ctx[:picked].created_at)}  #{WIKI.page_url(ctx[:picked].locale, ctx[:picked].path)}" }
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
             item:  ->(p, i) { "#{c(:gray, "#{i}.")} #{c(:magenta, p.title)}  #{c(:gray, fmt_date(p.created_at))}" },
             hint:  ->(p, i) { p.description.to_s.strip[0...65] } do
          fetch :page_body, loading: 'Loading page...' do |ctx|
            WIKI.content(ctx[:picked].id)
          end
          line color: :magenta
          text(style: :white) { |ctx| ctx[:picked].title }
          text(style: :muted) { |ctx| "#{fmt_date(ctx[:picked].created_at)}  #{WIKI.page_url(ctx[:picked].locale, ctx[:picked].path)}" }
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
          next "  #{c(:red, 'Could not load catalog.')}\r\n" unless games.any?

          render do
            games.each_with_index do |game, i|
              sep
              cols cyan: "#{i + 1}. #{game.title}", gray: "#{game.platform}  #{game.author}"
              para game.desc
              badge :green,   '[▶ Play]'     unless game.play_path.empty?
              badge :yellow,  '[⬇ Download]' unless game.download_path.empty?
              badge :blue,    '[Source]'     unless game.source_path.empty?
              badge :magenta, '[Docs]'       unless game.docs_path.empty?
              line CATALOG.play_url(game.play_path), :gray unless game.play_path.empty?
              line "#{game.release_count} versions available", :gray if game.release_count > 1
            end
            sep
            line CatalogRepository::GAMES_URL, :gray
          end
        end
        wait_enter
      end

      option 'Online Users' do
        section 'Online Users', color: :yellow
        rows do |ctx|
          ONLINE.snapshot.sort.map do |sid, name|
            marker = sid == ctx[:session_id] ? "  #{c(:gray, '← you')}" : ''
            "#{c(:white, name)}#{marker}"
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
