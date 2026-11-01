# frozen_string_literal: true

module UI
  # The board on a modern terminal (ANSI/xterm): the debrief terminal of the
  # gem's modern face, then the board hangs up.
  module Modern
    GOODBYE = "\e[0m\r\n  \e[1;37mThanks for calling Impostor BBS.\e[0m\r\n  " \
              "\e[2;37mMore of us: teletypegames.org\e[0m\r\n\r\n  \e[1;31mNO CARRIER\e[0m\r\n\r\n"

    def self.flow(bbs)
      debrief = Impostor::Modern.flow(sessions: bbs.sessions)
      BBS::Flow.define do
        call do |ctx, runner|
          BBS::FlowRunner.new(runner.session, ctx[:session_id], debrief, context: ctx).run
          nil
        end
        call do |_ctx, runner|
          runner.write GOODBYE
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
