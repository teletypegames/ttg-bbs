# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The classic literature vault of Teletype Games on a telnet line, two faces
# on one port: an ANSI terminal gets the modern desktop with a reader
# window, a Commodore 64 the PETSCII screens with 38-column pages.
Rubbs.board 'Scriptorium BBS', ScriptoriumBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye "The books are Project Gutenberg's gift."
  idle    900
end
