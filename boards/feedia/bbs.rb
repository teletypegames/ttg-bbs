# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# An RSS reader on a telnet line, two faces on one port: an ANSI terminal
# gets the modern desktop, a Commodore 64 the PETSCII screens.
Rubbs.board 'Feedia BBS', FeediaBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye "The stories are their publishers'."
end
