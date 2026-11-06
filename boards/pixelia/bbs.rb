# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The PETSCII & ANSI art gallery of Teletype Games on a telnet line, two faces
# on one port: an ANSI terminal gets the modern desktop, a Commodore 64 the
# PETSCII screens. Both paint on one canvas.
board = Rubbs.board 'Pixelia BBS', PixeliaBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  auth    login: :menu
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye color: UI::Petscii::PU
  on_session_end { |session, bbs| bbs.canvas.leave(session.session_id) }
end

board.run! if Rubbs.main?(__FILE__)
