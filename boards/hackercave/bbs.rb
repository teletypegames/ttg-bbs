# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The hacker's reading room of Teletype Games on a telnet line, two faces on
# one port: the caller picks a terminal (BBS::Terminal guesses it first), and
# an ANSI terminal gets the modern desktop with the RFCs as published, a
# Commodore 64 the PETSCII screens with the RFCs reflowed to 38 columns.
# Mouse reporting waits for the choice: its escape sequence would be garbage
# on a C64.
bbs = HackerCaveBBS.new

BBS.configure do |config|
  config.log_tag          = 'hackercave-bbs'
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 900

  config.flow = BBS::Terminal.flow(title: 'HackerCave BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs),
                                   splash: TTG::Logo.splash)
end

bbs.start
BBS.start
