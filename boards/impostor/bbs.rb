# frozen_string_literal: true

require 'bundler/setup'
require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# The debrief terminal of Definitely not an Impostor, two faces on one port:
# BBS::Terminal asks which terminal is calling, and a Commodore 64 gets the
# same terminal drawn for 40 columns in PETSCII. When the debrief ends, the
# board says goodbye and hangs up.
bbs = ImpostorBBS.new

BBS.configure do |config|
  config.idle_seconds = 600

  config.flow = BBS::Terminal.flow(title: 'Impostor BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

BBS.start
