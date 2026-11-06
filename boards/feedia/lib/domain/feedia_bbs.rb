# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the feed service wired
# to the feed list and the feeds. What callers send the editors goes to the
# network's feedback (ttg-common TTG::Feedback, on TTG Gate BBS); the
# messages of the board's own inbox from before are handed over to it once
# (#export_inbox) and kept here, marked.
class FeediaBBS
  include Rubbs::Common::Board::Domain

  path :db, 'data/feedia.sqlite3'
  path :feed_list, 'config/feeds.yml', env: 'FEEDS'
  database :db, MIGRATIONS

  service(:feeds) { FeedService.new(FeedListRepository.new(feed_list), FeedRepository.new) }

  background('inbox export', every: 600) { export_inbox }

  # Hands the inbox's messages not yet handed over to the network's feedback,
  # INBOX_BATCH at a time; raises when the Central does not take them (the
  # background job tries again). Returns how many went.
  def export_inbox
    sent = 0
    while (batch = MessageModel.unexported(INBOX_BATCH)).any?
      answer = TTG::Feedback.box.call(:import, nil, rows: batch.map(&:to_feedback))
      raise "the Central did not take the inbox: #{answer['result']}" unless answer['result'] == 'ok'

      MessageModel.exported(batch)
      sent += batch.size
    end
    Rubbs.log('inbox export', 'handed over', count: sent) if sent.positive?
    sent
  end

  # Messages handed over in one request.
  INBOX_BATCH = 20
end
