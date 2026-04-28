# frozen_string_literal: true

require 'bbs'
require_relative 'lib/online_users'
require_relative 'lib/message_board'
require_relative 'lib/wiki'
require_relative 'lib/catalog'
require_relative 'lib/display'

ONLINE   = OnlineUsers.new
MESSAGES = MessageBoard.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiClient.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogClient.new

BBS.configure do |c|
  c.on_session_end = ->(session) { ONLINE.remove(session.session_id) }

  c.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success

    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(v) { v.strip.empty? ? 'Anonymous' : v.strip[0...20] }

    call do |ctx, runner|
      ONLINE.add(runner.session_id, ctx[:username])
    end

    menu 'Choice', loop: true do
      option 'Message Board' do
        call { |ctx, runner| Display.render_messages(MESSAGES.last(30), runner) }
      end

      option 'New Message' do
        ask :message_text, prompt: 'Message (max 200 chars)', validate: :non_empty
        call do |ctx, runner|
          MESSAGES.append(ctx[:username], ctx[:message_text][0...200])
          runner.write "\r\n  #{Display::GREEN}Sent.#{Display::RESET}\r\n\r\n"
        end
      end

      option 'Blog Posts' do
        call { |ctx, runner| Display.render_wiki_list(WIKI, 'blog', 'Blog Posts', Display::BLUE, runner) }
      end

      option 'HowTo Guides' do
        call { |ctx, runner| Display.render_wiki_list(WIKI, 'howto', 'HowTo Guides', Display::MAGENTA, runner) }
      end

      option 'Game Catalog' do
        call { |ctx, runner| Display.render_catalog(CATALOG, runner) }
      end

      option 'Online Users' do
        call { |ctx, runner| Display.render_online(ONLINE, runner.session_id, ctx[:username], runner) }
      end

      option 'System Info' do
        call { |ctx, runner| Display.render_sysinfo(ONLINE, MESSAGES, runner) }
      end

      option 'Exit' do
        exit_menu
      end
    end

    say 'Goodbye!', style: :muted
  end
end

BBS.start
