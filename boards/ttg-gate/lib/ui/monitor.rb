# frozen_string_literal: true

module UI
  # The way to Monitor BBS (Grafana's dashboards on the line): a place in
  # the profile of the callers with the grafana role, and nowhere else (not
  # on the list of our boards, not on bbsweb). The board runs in the same
  # container and is not published on the host, so the gate dials it on
  # its own address (127.0.0.1) and hands the caller on signed in; the
  # board checks the role again.
  module Monitor
    # The role that opens the place.
    ROLE = 'grafana'

    # The board the place dials: its id, name, host and port (as
    # UI.dial reads a BoardModel).
    Board = Data.define(:id, :name, :host, :port)

    # Whether the caller on +session+ may call Monitor BBS.
    def self.allowed?(session) = session.identity.role?(ROLE)

    # Puts Monitor BBS in the profile of every caller with the role: the
    # board on +host+:+port+.
    def self.offer(host:, port:)
      board = Board.new(id: 'monitor-bbs', name: 'Monitor BBS', host: host, port: port)
      Rubbs::Common::Auth::Profile.extra(:monitor, 'Monitor BBS', hotkey: 'm', if: ->(session) { allowed?(session) }) do |session|
        UI.dial(session, board)
      end
    end
  end
end
