# frozen_string_literal: true

require 'rubbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The file area of Teletype Games on a telnet line, two faces on one port: an
# ANSI terminal gets the modern desktop with ZMODEM and XMODEM, a Commodore 64
# the PETSCII screens with XMODEM.
Rubbs.board 'WarpEngine BBS', WarpEngineBBS, slug: 'warp-engine-bbs' do
  preset  TTG::PRESET
  central TTG::CENTRAL
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye color: Rubbs::Petscii::Colors::LB
end
