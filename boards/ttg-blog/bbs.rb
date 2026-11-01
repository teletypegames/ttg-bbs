# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'
require_relative 'lib/web/api'

# The Teletype Games blog on a telnet line, two faces on one port: the caller
# picks a terminal (BBS::Terminal guesses it first), and both faces read and
# write line by line, 80 columns of ANSI or 40 of PETSCII. Readers need no
# account; the editors log in from the menu, and bin/user manages them.
# Beside the telnet line, Web::Api serves the posts to teletypegames.org.
bbs = TTGBlogBBS.new

Web::Api.new(bbs, port: bbs.http_port).start if bbs.http_port.positive?

BBS.configure do |config|
  config.mouse            = false
  config.mouse_on_connect = false
  config.idle_seconds     = 900

  config.flow = BBS::Terminal.flow(title: 'TTG Blog BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

BBS.start
