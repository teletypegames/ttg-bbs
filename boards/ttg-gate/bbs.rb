# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# TTG Gate BBS: one port for the whole Teletype BBS network. The caller picks a
# terminal (BBS::Terminal guesses it first), then a board from the menu, and
# the gate hands the line on to that board's port with a telnet gateway of
# rubbs; when the board hangs up the caller is back at the menu.
bbs = TTGGateBBS.new

BBS.configure do |config|
  config.mouse            = false
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.flow = BBS::Terminal.flow(title: 'TTG Gate BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

BBS.start
