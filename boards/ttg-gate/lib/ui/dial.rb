# frozen_string_literal: true

module UI
  # Hands the caller's line to +board+ through a telnet gateway of rubbs. The
  # board runs its own code on its own port; the call comes back here when it
  # hangs up and the caller pressed a key. Raises IOError when the caller
  # hangs up meanwhile. Our own boards are on the host (host.docker.internal,
  # a private address), so this gateway may call a non-public address; a
  # board of the catalog never goes through it (dial_catalog). It forwards
  # who is calling (the face picked here, the caller's address): our board
  # skips its terminal question and logo, and counts the real caller.
  def self.dial(session, board)
    BBS::Gateway.new(host: board.host, port: board.port, name: board.name, public_only: false, forward: true).call(session)
  end

  # Dials +board+ of Global Discovery (a Discovery::ListingModel) by the rules
  # of +dials+ (Discovery::DialService): the gateway's report becomes the
  # dial's probe, and a line silent both ways for the rules' +idle+ seconds
  # ends. A C64 calling an ASCII board gets it translated
  # (ListingModel#translated_for_c64?). Returns the Refusal when the rules keep the call from going,
  # else the dial's Call. Raises IOError when the caller hangs up meanwhile.
  def self.dial_catalog(session, dials, caller, board, face:)
    dials.dial(caller, board, face: face) do |call|
      gateway = BBS::Gateway.new(
        host:            call.ip,
        port:            board.port,
        name:            board.title,
        connect_timeout: ::Discovery::DialService::CONNECT_TIMEOUT,
        idle:            dials.idle,
        translate:       face == :petscii && board.translated_for_c64?
      )
      gateway.call(session) { |report| call.report = report }
    end
  end

  # The key a caller's dials are counted by (Discovery::DialService.caller_key).
  def self.caller_key(session)
    ::Discovery::DialService.caller_key(BBS::RateLimit.peer(session), session.session_id)
  end
end
