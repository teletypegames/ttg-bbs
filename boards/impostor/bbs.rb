# frozen_string_literal: true

require 'bundler/setup'
require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui'

# The debrief terminal of Definitely not an Impostor, two faces on one port:
# a Commodore 64 gets the same terminal drawn for 40 columns in PETSCII. When
# the debrief ends, the board says goodbye under it and hangs up.
board = Rubbs.board 'Impostor BBS', ImpostorBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  modern  { |bbs| flow Impostor::Modern.flow(sessions: bbs.debriefs) }
  petscii { |bbs| flow Impostor::Petscii.flow(sessions: bbs.debriefs) }
  goodbye(**UI::GOODBYE)
end

board.run! if Rubbs.main?(__FILE__)
