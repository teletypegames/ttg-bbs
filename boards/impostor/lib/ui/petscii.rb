# frozen_string_literal: true

require_relative 'petscii/screen'

module UI
  # The board on a Commodore 64: the debrief terminal of the gem's PETSCII
  # face, then the board's logo and goodbye, and it hangs up. The line is
  # already PETSCII, so the gem's ANSI colours become the C64's own.
  module Petscii
    LOGO_COLORS = [GN, GN, GN, YE, YE].freeze

    # IMPOSTOR in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii('IMPOSTOR', colors: LOGO_COLORS, indent: 2)

    def self.flow(bbs)
      debrief = Impostor::Petscii.flow(sessions: bbs.sessions)
      BBS::Flow.define do
        call do |ctx, runner|
          BBS::FlowRunner.new(runner.session, ctx[:session_id], debrief, context: ctx).run
          nil
        end
        call do |_ctx, runner|
          Petscii.goodbye(Screen.new(runner.session))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(screen)
      BBS::Goodbye.petscii(screen, bar: 'Thanks for calling Impostor BBS', color: GN) do |s|
        logo.each { |line| s.puts line }
        s.puts
        s.say("More of us: #{BBS::Goodbye::URL}", GR)
      end
    end
  end
end
