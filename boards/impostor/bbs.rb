# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui'

# The debrief terminal of Definitely not an Impostor, two faces on one port:
# a Commodore 64 gets the same terminal drawn for 40 columns in PETSCII. When
# the debrief ends, the board says goodbye under it and hangs up.
BBS.board 'Impostor BBS', ImpostorBBS do
  preset TTG::PRESET
  modern do |bbs|
    call(&UI.debrief(Impostor::Modern.flow(sessions: bbs.debriefs)))
    call { UI.goodbye(session) }
  end
  petscii do |bbs|
    call(&UI.debrief(Impostor::Petscii.flow(sessions: bbs.debriefs)))
    call { UI::Petscii.goodbye(session) }
  end
  goodbye false
end
