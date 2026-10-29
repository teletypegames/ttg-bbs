# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain/wikipedia'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'

# Wikipedia on a telnet line, two faces on one port: the caller picks a
# terminal (BBS::Terminal guesses it first), and an ANSI terminal gets the modern
# desktop, a Commodore 64 the PETSCII screens. Mouse reporting waits for the
# choice: its escape sequence would be garbage on a C64.
wikipedia = Wikipedia.new(languages: ENV.fetch('ALEXANDRIA_LANGUAGES', 'en,hu').split(',').map(&:strip).reject(&:empty?))

BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.flow = BBS::Terminal.flow(title: 'Alexandria BBS', modern: UI::Modern.flow(wikipedia), c64: UI::Petscii.flow(wikipedia))
end

BBS.start
