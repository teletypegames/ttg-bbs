# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# TTG Mail BBS: two faces on one port, a modern terminal and a Commodore 64.
Rubbs.board 'TTG Mail BBS', TTGMailBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
end
