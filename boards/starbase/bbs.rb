# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# A Star Trek library on a telnet line, two faces on one port: a modern
# terminal gets the desktop, a Commodore 64 the PETSCII screens.
board = Rubbs.board 'Starbase BBS', StarbaseBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  badges  TTG::Badges.load(__dir__)
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'Articles from memory-alpha.fandom.com, under CC BY-NC.'
end

board.run! if Rubbs.main?(__FILE__)
