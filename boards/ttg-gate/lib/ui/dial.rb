# frozen_string_literal: true

module UI
  # Hands the caller's line to +board+ through a telnet gateway of rubbs. The
  # board runs its own code on its own port; the call comes back here when it
  # hangs up and the caller pressed a key. Raises IOError when the caller
  # hangs up meanwhile.
  def self.dial(session, board)
    BBS::Gateway.new(host: board.host, port: board.port, name: board.name).call(session)
  end
end
