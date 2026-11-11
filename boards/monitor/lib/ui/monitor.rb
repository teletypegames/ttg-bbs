# frozen_string_literal: true

module UI
  # The way in, the same on either face: a caller without the board's role
  # (MonitorBBS::ROLE) is told so and the call ends; one with it gets the
  # dashboards (UI::Home and the pages after it) on a modern terminal or a
  # C64.
  module Monitor
    # Seconds the refusal stays before the call ends.
    REFUSAL_WAIT = 15

    # Whether the caller on +session+ may see the dashboards.
    def self.allowed?(session) = session.identity.role?(MonitorBBS::ROLE)

    # Runs the board for the call of +runner+ (the flow's
    # Rubbs::Common::Call::FlowRunner) with +bbs+ (the MonitorBBS). Returns
    # +:halt+ for a caller who may not come in.
    def self.call(runner, bbs)
      session = runner.session
      return refuse(runner, session) unless allowed?(session)

      Rubbs.log('monitor', 'opened', user: session.identity.name.to_s)
      Rubbs::Common::Screens::Pages.new(session, charset: :lower).run(Home.new(bbs.grafana))
      nil
    end

    # Tells the caller the board is not for them; +:halt+.
    def self.refuse(runner, session)
      Rubbs.log('monitor', 'refused', user: session.identity.name.to_s, ip: session.caller_ip.to_s)
      runner.line('Monitor BBS is open only to accounts with the grafana role.', style: :error)
      runner.line('Press a key.')
      session.readkey(timeout: REFUSAL_WAIT)
      :halt
    end
  end
end
