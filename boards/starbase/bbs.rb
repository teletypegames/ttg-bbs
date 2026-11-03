# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# A Star Trek library on a telnet line, two faces on one port: a modern
# terminal gets the desktop, a Commodore 64 the PETSCII screens.
BBS.board 'Starbase BBS', StarbaseBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'Articles from memory-alpha.fandom.com, under CC BY-NC.'
end
