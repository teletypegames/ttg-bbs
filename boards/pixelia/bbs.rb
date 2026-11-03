# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The PETSCII & ANSI art gallery of Teletype Games on a telnet line, two faces
# on one port: an ANSI terminal gets the modern desktop, a Commodore 64 the
# PETSCII screens. Both paint on one canvas.
BBS.board 'Pixelia BBS', PixeliaBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  on_session_end { |session, bbs| bbs.canvas.leave(session.session_id) }
end
