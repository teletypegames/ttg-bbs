# frozen_string_literal: true

module UI
  # Hands the caller's line to +board+ through a telnet gateway of rubbs. The
  # board runs its own code on its own port; the call comes back here when it
  # hangs up and the caller pressed a key. Raises IOError when the caller
  # hangs up meanwhile.
  def self.dial(session, board)
    BBS::Gateway.new(host: board.host, port: board.port, name: board.name).call(session)
  end

  # Dials +board+ of Global Discovery (a Discovery::ListingModel) by the rules
  # of +dials+ (Discovery::DialService): the gateway's report becomes the
  # dial's probe. Returns the Refusal when the rules keep the call from going,
  # else the dial's Call. Raises IOError when the caller hangs up meanwhile.
  def self.dial_catalog(session, dials, caller, board, face:)
    dials.dial(caller, board, face: face) do |call|
      gateway = BBS::Gateway.new(host: call.ip, port: board.port, name: board.title,
                                 connect_timeout: ::Discovery::DialService::CONNECT_TIMEOUT)
      gateway.call(session) { |report| call.report = report }
    end
  end

  # The key a caller's dials are counted by (Discovery::DialService.caller_key).
  def self.caller_key(session)
    ip = session.line.remote_address.ip_address
    ::Discovery::DialService.caller_key(ip, session.session_id)
  rescue StandardError
    ::Discovery::DialService.caller_key(nil, session.session_id)
  end
end
