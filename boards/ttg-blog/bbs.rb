# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'
require_relative 'lib/web/api'

# The Teletype Games blog on a telnet line, two faces on one port, both line
# by line: 80 columns of ANSI or 40 of PETSCII. Readers need no account; the
# editors (the blogger role) log in from the menu with their Teletype Games
# account, or come in logged in from TTG Gate BBS. Beside the telnet line,
# Web::Api serves the posts to teletypegames.org.
Rubbs.board 'TTG Blog BBS', TTGBlogBBS do
  preset  TTG::PRESET
  auth    TTG::AUTH, login: :menu
  modern  UI::Modern
  petscii UI::Petscii
  idle 900
  mouse false
  goodbye greeting: 'Thanks for reading', color: Rubbs::Petscii::Colors::YE
  on_start { |bbs| Web::Api.new(bbs, port: bbs.http_port).start if bbs.http_port.positive? }
end
