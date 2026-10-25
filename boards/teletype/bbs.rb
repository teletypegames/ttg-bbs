# frozen_string_literal: true

require_relative 'lib/domain'
require_relative 'lib/ui/terminal'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/c64'

# One board, two faces: the caller picks a terminal (the board guesses it
# first), and an ANSI terminal gets the modern desktop, a Commodore 64 the
# PETSCII board. Both work on the same TeletypeBBS. Mouse reporting waits for
# the choice: its escape sequence would be garbage on a C64.
bbs    = TeletypeBBS.new
faces  = { modern: UI::Modern.flow(bbs), c64: UI::C64.flow(bbs) }

BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.on_session_end = ->(session) { bbs.end_call(session.session_id) }

  config.flow = BBS::Flow.define do
    call do |ctx, runner|
      face = UI::Terminal.choose(runner.session)
      next :halt if face.nil?

      face == :c64 ? runner.session.petscii! : runner.session.enable_mouse
      BBS::FlowRunner.new(runner.session, ctx[:session_id], faces[face], context: ctx).run
      nil
    end
  end
end

BBS.start
