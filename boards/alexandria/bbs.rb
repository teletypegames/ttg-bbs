# frozen_string_literal: true

require 'bbs'
require 'ttg/common'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# Wikipedia on a telnet line, two faces on one port: a modern terminal gets
# the desktop, a Commodore 64 the PETSCII screens.
BBS.board 'Alexandria BBS', AlexandriaBBS do
  preset  TTG::PRESET
  modern  UI::Modern::APP
  petscii UI::Petscii
  goodbye 'Articles from wikipedia.org, under CC BY-SA.'
end
