# frozen_string_literal: true

module UI
  # The logon of both faces: the name and the password written into the
  # guestbook of a face's clubhouse entrance, and the caller let in or
  # turned away. The entrance draws; this decides.
  #
  # An entrance answers #show, #ask_name, #ask_password (nil when the line
  # drops), #wrong_password, #turn_away(text) and #listed? (whether the
  # caller goes on the node list).
  module Login
    # Lets the caller of +runner+ (a BBS::FlowRunner) in through +entrance+.
    # Returns :halt when they do not get in, which ends the call.
    def self.call(runner, bbs, entrance)
      runner.context[:call_started] = Time.now
      entrance.show
      typed = entrance.ask_name or return :halt
      result = bbs.log_on(runner.context, typed, caller_key: runner.session.caller_key, listed: entrance.listed?) do |again|
        entrance.wrong_password if again
        entrance.ask_password
      end
      return if TeletypeBBS::LET_IN.include?(result)

      entrance.turn_away(Wording.turned_away(runner.context[:username], result))
      :halt
    rescue *BBS::LINE_DROPPED
      :halt
    rescue StandardError => e
      BBS.log('login', e)
      :halt
    end
  end
end
