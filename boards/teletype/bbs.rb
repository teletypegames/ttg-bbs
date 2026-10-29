# frozen_string_literal: true

require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# One board, two faces: the caller picks a terminal (BBS::Terminal guesses it
# first), and an ANSI terminal gets the modern desktop, a Commodore 64 the
# PETSCII board. Both work on the same TeletypeBBS. Mouse reporting waits for
# the choice: its escape sequence would be garbage on a C64.
bbs = TeletypeBBS.new

BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.on_session_end = ->(session) { bbs.end_call(session.session_id) }

  config.flow = BBS::Terminal.flow(title: 'Teletype BBS', modern: UI::Modern.flow(bbs), c64: UI::Petscii.flow(bbs))
end

BBS.start
