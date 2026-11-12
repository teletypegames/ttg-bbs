# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui'

# Monitor BBS: Grafana's dashboards on a telnet line, on a modern terminal
# and on a Commodore 64, for the accounts of the network with the grafana
# role only. Every caller logs in first (a call handed on by TTG Gate BBS
# comes signed in); one without the role is turned away. The gate lists it
# only for those who have the role.
board = Rubbs.board 'Monitor BBS', MonitorBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  auth    login: :call, guests: false
  mouse   false
  modern  { |bbs| call { UI::Monitor.call(self, bbs) } }
  petscii { |bbs| call { UI::Monitor.call(self, bbs) } }
  goodbye 'Monitor BBS reads Grafana with a viewer token: what you saw is what grafana.teletypegames.org shows.'
end

board.run! if Rubbs.main?(__FILE__)
