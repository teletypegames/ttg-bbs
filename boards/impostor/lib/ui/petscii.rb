# frozen_string_literal: true

module UI
  # The board on a Commodore 64: the debrief terminal of the gem's PETSCII
  # face, then the board hangs up. The line is already PETSCII, so ANSI
  # colours become the C64's own.
  module Petscii
    def self.flow(bbs)
      debrief = Impostor::Petscii.flow(sessions: bbs.sessions)
      BBS::Flow.define do
        call do |ctx, runner|
          BBS::FlowRunner.new(runner.session, ctx[:session_id], debrief, context: ctx).run
          nil
        end
        call do |_ctx, runner|
          Petscii.goodbye(runner)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(runner)
      runner.write "\e[0m\r\n \e[1;32m\e[7m#{' Thanks for calling Impostor BBS'.ljust(39)}\e[27m\e[0;37m\r\n\r\n"
      runner.write " \e[2;37mMore of us: teletypegames.org\e[0;37m\r\n\r\n"
      sleep 1.2
      runner.write " +++\r\n"
      sleep 0.6
      runner.write " ATH0\r\n"
      sleep 0.4
      runner.write " \e[1;31mNO CARRIER\e[0;37m\r\n\r\n"
    end
  end
end
