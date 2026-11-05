# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The hacker's reading room of Teletype Games on a telnet line, two faces on
# one port: an ANSI terminal gets the modern desktop with the RFCs as
# published, a Commodore 64 the PETSCII screens with the RFCs reflowed to 38
# columns.
Rubbs.board 'HackerCave BBS', HackerCaveBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'The RFCs are the work of the IETF and the RFC Editor.'
  idle 900
end
