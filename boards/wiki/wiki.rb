# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/wiki/client'

# WIKI-BBS — the Teletype Games wiki over telnet. One wiki, two faces: the
# caller picks a terminal (the board guesses it first), and an ANSI terminal
# gets the modern full-screen browser (page tree on the left, the page
# rendered as ANSI markdown on the right), a Commodore 64 a PETSCII tree of
# numbered lists. Content comes live from the Grav wiki's
# /custom/sitemap.json and /custom/page.json endpoints.
# Pages flagged private on the wiki (access: site.login) stay locked until the
# caller unlocks the session with this password (Wiki menu > Supervisor login,
# S on the C64). The wiki holds the same secret and only serves private page
# bodies to requests carrying it as ?token= — so the lock is enforced
# server-side too.
SUPERVISOR_PASSWORD = ENV['SUPERVISOR_PASSWORD'].to_s

WIKI = Wiki::Client.new(base_url: ENV['WIKI_URL'] || 'http://localhost:9120',
                        token: SUPERVISOR_PASSWORD)

require_relative 'lib/ui/terminal'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/c64'

# Load the page index once at boot; sessions share it. If the wiki is down,
# start anyway — callers can pull it in later with Wiki > Refresh index.
begin
  WIKI.refresh_index!
  puts "wiki-bbs: indexed #{WIKI.pages.size} pages from #{WIKI.base_url}"
rescue StandardError => e
  warn "wiki-bbs: could not load wiki index at boot " \
       "(#{e.class}: #{e.message}) — use Wiki > Refresh index"
end

faces = { modern: UI::Modern.flow(WIKI), c64: UI::C64.flow(WIKI) }

# Mouse reporting waits for the choice: its escape sequence would be garbage
# on a C64.
BBS.configure do |config|
  config.port             = (ENV['BBS_PORT'] || 2323).to_i
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = (ENV['BBS_IDLE'] || 900).to_i

  config.flow = BBS::Flow.define do
    call do |ctx, runner|
      face = UI::Terminal.choose(runner.session)
      next :halt if face.nil?

      face == :c64 ? runner.session.petscii! : runner.session.enable_mouse
      BBS::FlowRunner.new(runner.session, ctx[:session_id], faces[face], context: ctx).run
      nil
    end
  end
end

BBS.start
