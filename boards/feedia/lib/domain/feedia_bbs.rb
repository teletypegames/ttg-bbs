# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the feed service wired
# to the feed list and the feeds, the inbox service to the board's database
# and the Discord webhook. The one place that reads the environment; both
# faces (lib/ui/modern, lib/ui/petscii) and bin/inbox work on one instance
# of it.
class FeediaBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :feeds, :inbox

  def initialize
    @feeds = FeedService.new(FeedListRepository.new(ENV.fetch('FEEDIA_BBS_FEEDS', File.join(ROOT, 'config/feeds.yml'))),
                             FeedRepository.new)
    @inbox = InboxService.new(inbox_repository, discord: DiscordRepository.new(ENV.fetch('FEEDIA_BBS_DISCORD_WEBHOOK', '')))
  end

  # The services by name.
  def services = { feeds: @feeds, inbox: @inbox }

  private

  # The inbox in the board's database; the inbox.jsonl of earlier versions
  # beside it is taken in on the first start.
  def inbox_repository
    db = BBS::SQLite.new(ENV.fetch('FEEDIA_BBS_DB', File.join(ROOT, 'data/feedia.sqlite3')))
    InboxRepository.new(db, legacy: File.join(File.dirname(db.path), 'inbox.jsonl'))
  end
end
