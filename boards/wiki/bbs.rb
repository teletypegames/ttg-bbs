# frozen_string_literal: true

require 'bundler/setup'
require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# TTG Wiki BBS — the Teletype Games wiki over telnet. One wiki, two faces: an
# ANSI terminal gets the modern full-screen browser (page tree on the left,
# the page rendered as ANSI markdown on the right), a Commodore 64 a PETSCII
# tree of numbered lists. Content comes live from the Grav wiki's
# /custom/sitemap.json and /custom/page.json endpoints.
# Pages flagged private on the wiki (access: site.login) are for the
# supervisors: the accounts of the network with the wiki-supervisor role, who
# log in from the menu (Wiki > Log in, L on the C64) or come in logged in from
# TTG Gate BBS. The board asks the wiki for a private page body with its own
# token (the X-Wiki-Token header, WIKI_BBS_SUPERVISOR_PASSWORD), only for a
# supervisor and only for private pages (WikiRepository#page).
Rubbs.board 'TTG Wiki BBS', WikiBBS, slug: 'wiki-bbs' do
  preset TTG::PRESET
  auth TTG::AUTH, login: :menu
  modern do |bbs|
    big_banner 'TTG WIKI', style: :success
    text(style: :muted) { "Teletype Games wiki over telnet — #{bbs.wiki.pages.size} pages indexed." }
    app UI::Modern::APP
  end
  petscii UI::Petscii
  goodbye { |context, session| UI::Wording.goodbye(context, session) }
  idle(&:idle_seconds)
end
