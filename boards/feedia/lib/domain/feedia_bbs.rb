# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the feed service wired
# to the feed list and the feeds, the inbox service to the board's database
# and the Discord webhook. Both faces and bin/inbox work on one instance of
# it.
class FeediaBBS
  include BBS::Domain

  setting :discord_webhook, ''
  path    :db, 'data/feedia.sqlite3'
  path    :feed_list, 'config/feeds.yml', env: 'FEEDS'

  service(:feeds) { FeedService.new(FeedListRepository.new(feed_list), FeedRepository.new) }
  service(:inbox) { InboxService.new(inbox_repository, discord: DiscordRepository.new(discord_webhook)) }

  private

  # The inbox in the board's database; the inbox.jsonl of earlier versions
  # beside it is taken in on the first start.
  def inbox_repository = InboxRepository.new(database(db), legacy: File.join(File.dirname(db), 'inbox.jsonl'))
end
