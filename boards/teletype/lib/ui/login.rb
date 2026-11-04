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
    # Lets the caller of +runner+ (a BBS::FlowRunner) in through +entrance+:
    # one who came signed in (handed on by TTG Gate BBS) as they are, any
    # other with the name and, for an account, the password they write in.
    # Returns :halt when they do not get in, which ends the call.
    def self.call(runner, bbs, entrance)
      runner.context[:call_started] = Time.now
      entrance.show
      identity = runner.session.identity
      identity = sign_in(runner, bbs, entrance) unless identity.signed_in?
      return :halt unless identity

      bbs.start_call(runner.context[:session_id], identity, listed: entrance.listed?)
      nil
    rescue *BBS::LINE_DROPPED
      :halt
    rescue StandardError => e
      BBS.log('login', e)
      :halt
    end

    # The name asked, and for an account its password (MemberService#log_on):
    # the BBS::Auth::Identity the caller comes in as, now the session's, or
    # nil when they are turned away.
    def self.sign_in(runner, bbs, entrance)
      typed = entrance.ask_name or return
      name = MemberService.normalize_name(typed)
      result = bbs.members.log_on(name, caller_key: runner.session.caller_key) do |again|
        entrance.wrong_password if again
        entrance.ask_password
      end
      return runner.session.identity = result if result.is_a?(BBS::Auth::Identity)

      entrance.turn_away(Wording.turned_away(name, result)) unless result == :dropped
      nil
    end
  end
end
