# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# Starbase BBS: two faces on one port. The caller picks a terminal (BBS::Terminal guesses
# first); mouse reporting waits for the choice, its escape would be garbage on a C64.
bbs = StarbaseBBS.new

BBS.configure do |config|
  config.log_tag          = 'starbase-bbs'
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.flow = BBS::Terminal.flow(title: 'Starbase BBS', modern: UI::Modern.flow(bbs), petscii: UI::Petscii.flow(bbs))
end

bbs.start
BBS.start
