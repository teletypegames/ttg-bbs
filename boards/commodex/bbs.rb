# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The Commodore 64 game compendium on a telnet line, two faces on one port: a
# modern terminal gets the desktop, a Commodore 64 the PETSCII screens.
board = Rubbs.board 'Commodex BBS', CommodexBBS do
  preset  TTG::PRESET
  central TTG::CENTRAL
  auth    login: :menu
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'Games from wikidata.org (CC0), stories from wikipedia.org (CC BY-SA).'
end

board.run! if Rubbs.main?(__FILE__)
