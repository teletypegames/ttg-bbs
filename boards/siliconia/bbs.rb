# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# Siliconia BBS: two faces on one port, a modern terminal and a Commodore 64.
board = Rubbs.board 'Siliconia BBS', SiliconiaBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  modern  UI::Modern::APP
  petscii UI::Petscii
end

board.run! if Rubbs.main?(__FILE__)
