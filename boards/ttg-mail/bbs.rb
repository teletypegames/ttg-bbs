# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# TTG Mail BBS: the letters between the accounts of the network, two faces on one port, a
# modern terminal and a Commodore 64. The accounts, the letters, the wall and the feedback are
# the Central's (TTG Gate BBS); a caller logs in with the network's account.
board = Rubbs.board 'TTG Mail BBS', TTGMailBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  auth    login: :menu
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'Your letters stay on TTG Gate BBS; read them from any board of the network that has mail.'
end

board.run! if Rubbs.main?(__FILE__)
