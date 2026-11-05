# frozen_string_literal: true

module UI
  # The start of a call on both faces. Who the caller is the splash
  # (BBS::Splash) already settled: logged in, registered, or a guest, or
  # signed in at TTG Gate BBS; here the call is put on the board.
  module Login
    # Starts the call of +runner+ (a BBS::FlowRunner) on +bbs+; +listed+
    # is whether the caller goes on the node list. Returns :halt when the
    # line dropped, which ends the call.
    def self.call(runner, bbs, listed:)
      context = runner.context
      context[:call_started] = Time.now
      bbs.start_call(context[:session_id], runner.session.identity, listed: listed)
      context[:caller_number] = bbs.last_callers.caller_number
      nil
    rescue *BBS::LINE_DROPPED
      :halt
    rescue StandardError => e
      BBS.log('login', e)
      :halt
    end
  end
end
