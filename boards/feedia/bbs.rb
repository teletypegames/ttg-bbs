# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain/feeds'
require_relative 'lib/domain/inbox'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/c64'

# An RSS reader on a telnet line, two faces on one port: the caller picks a
# terminal (BBS::Terminal guesses it first), and an ANSI terminal gets the modern
# desktop, a Commodore 64 the PETSCII screens. Mouse reporting waits for the
# choice: its escape sequence would be garbage on a C64.
feeds = Feeds.load(ENV.fetch('FEEDIA_FEEDS', File.join(__dir__, 'config/feeds.yml')))
inbox = Inbox.new(path: ENV.fetch('FEEDIA_INBOX', File.join(__dir__, 'data/inbox.jsonl')),
                  webhook: ENV.fetch('FEEDIA_DISCORD_WEBHOOK', ''))

BBS.configure do |config|
  config.mouse            = true
  config.mouse_on_connect = false
  config.idle_seconds     = 600

  config.flow = BBS::Terminal.flow(title: 'Feedia', modern: UI::Modern.flow(feeds, inbox), c64: UI::C64.flow(feeds, inbox))
end

BBS.start
