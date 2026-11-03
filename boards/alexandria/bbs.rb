# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# Wikipedia on a telnet line, two faces on one port: the caller picks a
# terminal (BBS::Terminal guesses it first), and an ANSI terminal gets the modern
# desktop, a Commodore 64 the PETSCII screens. Mouse reporting waits for the
# choice: its escape sequence would be garbage on a C64.
bbs = AlexandriaBBS.new

BBS.configure do |config|
  config.log_tag          = 'alexandria-bbs'
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.flow = BBS::Terminal.flow(title: 'Alexandria BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs),
                                   splash: TTG::Logo.splash)
end

BBS.start
