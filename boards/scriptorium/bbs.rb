# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The classic literature vault of Teletype Games on a telnet line, two faces
# on one port: the caller picks a terminal (BBS::Terminal guesses it first),
# and an ANSI terminal gets the modern desktop with a reader window, a
# Commodore 64 the PETSCII screens with 38-column pages. Mouse reporting
# waits for the choice: its escape sequence would be garbage on a C64.
bbs = ScriptoriumBBS.new

BBS.configure do |config|
  config.log_tag          = 'scriptorium-bbs'
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 900

  config.flow = BBS::Terminal.flow(title: 'Scriptorium BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

bbs.start
BBS.start
