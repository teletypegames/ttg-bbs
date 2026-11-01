# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# WIKI-BBS — the Teletype Games wiki over telnet. One wiki, two faces: the
# caller picks a terminal (BBS::Terminal guesses it first), and an ANSI terminal
# gets the modern full-screen browser (page tree on the left, the page
# rendered as ANSI markdown on the right), a Commodore 64 a PETSCII tree of
# numbered lists. Content comes live from the Grav wiki's
# /custom/sitemap.json and /custom/page.json endpoints.
# Pages flagged private on the wiki (access: site.login) stay locked until the
# caller unlocks the session with the supervisor password (Wiki menu >
# Supervisor login, S on the C64). The wiki holds the same secret and only
# serves private page bodies to requests carrying it as ?token= — so the lock
# is enforced server-side too.
$stdout.sync = true

# The page index loads at boot, in the background, and sessions share it.
bbs = WikiBBS.new
bbs.index_in_background

# Mouse reporting waits for the choice: its escape sequence would be garbage
# on a C64.
BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = bbs.idle_seconds

  config.flow = BBS::Terminal.flow(title: 'TTG Wiki', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

BBS.start
