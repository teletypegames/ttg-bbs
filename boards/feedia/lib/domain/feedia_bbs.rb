# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the feed service wired
# to the feed list and the feeds, the inbox service to the inbox file and
# the Discord webhook. The one place that reads the environment; both faces
# (lib/ui/modern, lib/ui/petscii) and bin/inbox work on one instance of it.
class FeediaBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :feeds, :inbox

  def initialize
    @feeds = FeedService.new(FeedListRepository.new(ENV.fetch('FEEDIA_FEEDS', File.join(ROOT, 'config/feeds.yml'))),
                             FeedRepository.new)
    @inbox = InboxService.new(InboxRepository.new(ENV.fetch('FEEDIA_INBOX', File.join(ROOT, 'data/inbox.jsonl'))),
                              discord: DiscordRepository.new(ENV.fetch('FEEDIA_DISCORD_WEBHOOK', '')))
  end

  # The services by name.
  def services = { feeds: @feeds, inbox: @inbox }
end
