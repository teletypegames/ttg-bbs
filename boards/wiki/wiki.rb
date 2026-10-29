# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/wiki/client'

# WIKI-BBS — the Teletype Games wiki over telnet. One wiki, two faces: the
# caller picks a terminal (BBS::Terminal guesses it first), and an ANSI terminal
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

require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

$stdout.sync = true

# Load the page index at boot; sessions share it. A stack deploy recreates
# grav together with this container, so the wiki is often not up yet: start
# anyway and keep retrying in the background until it answers. Callers can
# also pull it in with Wiki > Refresh index.
INDEX_RETRY = 10 # seconds

Thread.new do
  attempts = 0
  begin
    WIKI.refresh_index!
    puts "wiki-bbs: indexed #{WIKI.pages.size} pages from #{WIKI.base_url}"
  rescue StandardError => e
    attempts += 1
    if attempts == 1 || (attempts % 30).zero?
      warn "wiki-bbs: could not load wiki index (#{e.class}: #{e.message}), " \
           "retrying every #{INDEX_RETRY}s"
    end
    sleep INDEX_RETRY
    retry
  end
end

# Mouse reporting waits for the choice: its escape sequence would be garbage
# on a C64.
BBS.configure do |config|
  config.port             = (ENV['BBS_PORT'] || 2323).to_i
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = (ENV['BBS_IDLE'] || 900).to_i

  config.flow = BBS::Terminal.flow(title: 'TTG Wiki', modern: UI::Modern.flow(WIKI), petscii: UI::Petscii.flow(WIKI))
end

BBS.start
