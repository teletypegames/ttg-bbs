# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the feed service wired
# to the feed list and the feeds, the inbox service to the board's database
# and the Discord webhook. Both faces and bin/inbox work on one instance of
# it.
class FeediaBBS
  include Rubbs::Common::Board::Domain

  setting :discord_webhook, ''
  path    :db, 'data/feedia.sqlite3'
  path    :feed_list, 'config/feeds.yml', env: 'FEEDS'
  database :db, MIGRATIONS

  service(:feeds) { FeedService.new(FeedListRepository.new(feed_list), FeedRepository.new) }
  service(:inbox) do
    import_legacy_inbox
    InboxService.new(discord: DiscordRepository.new(discord_webhook))
  end

  private

  # The inbox.jsonl of earlier versions beside the database, taken in on
  # the first start.
  def import_legacy_inbox = LegacyInbox.new(File.join(File.dirname(db), 'inbox.jsonl')).import
end
