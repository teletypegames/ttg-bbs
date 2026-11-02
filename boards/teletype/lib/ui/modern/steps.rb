# frozen_string_literal: true

module UI
  module Modern
    # The steps of a modern call around the desktop: the modem and the
    # entrance, the logon sequence, and leaving.
    module Steps
      DROPPED = [IOError, Errno::EPIPE, Errno::ECONNRESET].freeze

      # The modem, then the entrance of the clubhouse, where the name and the
      # password go into the guestbook. :halt when the caller does not get in.
      def self.entrance(bbs, ctx, runner)
        Formatters::Logon.connect(runner)
        ctx[:call_started] = Time.now
        ctx[:caller_key]   = BBS::RateLimit.caller_key(runner.session)
        door = Clubhouse::Entrance.new(runner.session, bbs)
        door.show
        typed = door.ask_name
        return :halt if typed.nil?

        log_on(bbs, ctx, runner, door, AccountService.normalize_name(typed))
      rescue *DROPPED
        :halt
      rescue StandardError => e
        BBS.log('login', e)
        :halt
      end

      def self.log_on(bbs, ctx, runner, door, name)
        ctx[:username] = name
        result = bbs.accounts.log_on(name, caller_key: ctx[:caller_key]) do |again|
          door.wrong('Wrong password.') if again
          door.ask_password
        end
        ctx[:authenticated] = result == :ok
        return turned_away(runner, name, result) unless %i[ok guest].include?(result)

        # A terminal that never reported its size is a scanner, not a caller:
        # it may look around, but it is not listed anywhere.
        bbs.start_call(ctx[:session_id], name, listed: runner.session.naws_reported?)
        nil
      end

      def self.turned_away(runner, name, result)
        runner.write "\e[0m\e[2J\e[H\r\n  \e[1;31m#{Wording.turned_away(name, result)}\e[0m\r\n\r\n"
        :halt
      end

      # Who is calling, then the scans of the old boards.
      def self.logon(bbs, ctx, runner)
        summary = bbs.logon_summary(ctx[:username], registered: ctx[:authenticated], session_id: ctx[:session_id])
        ctx[:caller_number] = summary[:caller_number]
        Formatters::Logon.screen(runner, **summary)
        runner.session.readkey(timeout: 120)
        nil
      rescue *DROPPED
        :halt
      rescue StandardError => e
        BBS.log('logon screen', e)
        nil
      end

      def self.leaving(bbs, ctx, runner)
        Clubhouse::Leaving.play(runner, name: ctx[:username] || AccountService::ANONYMOUS,
                                        seconds: Time.now - (ctx[:call_started] || Time.now),
                                        caller_number: ctx[:caller_number] || bbs.last_callers.caller_number,
                                        quote: bbs.taglines.pick)
        nil
      rescue *DROPPED
        nil
      end
    end
  end
end
