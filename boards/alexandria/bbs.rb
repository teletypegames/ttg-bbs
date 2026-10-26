# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain/wikipedia'
require_relative 'lib/ui/terminal'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/c64'

# Wikipedia on a telnet line, two faces on one port: the caller picks a
# terminal (the proxy guesses it first), and an ANSI terminal gets the modern
# desktop, a Commodore 64 the PETSCII screens. Mouse reporting waits for the
# choice: its escape sequence would be garbage on a C64.
wikipedia = Wikipedia.new(languages: ENV.fetch('WIKIPROXY_LANGUAGES', 'en,hu').split(',').map(&:strip).reject(&:empty?))
faces     = { modern: UI::Modern.flow(wikipedia), c64: UI::C64.flow(wikipedia) }

BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

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
