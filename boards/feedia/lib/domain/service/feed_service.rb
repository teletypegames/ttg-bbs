# frozen_string_literal: true

# What a caller can read: the configured feeds, and what one of them says
# now (a ChannelModel, nil when it did not answer or sent no feed).
class FeedService
  def initialize(list, feeds)
    @list  = list
    @feeds = feeds
  end

  # The FeedModels, in the order of the list.
  def list = @list.all

  # The ChannelModel of +feed+; nil (logged) when it could not be fetched
  # or read. With +fresh+ the cache is skipped.
  def read(feed, fresh: false)
    @feeds.read(feed, fresh: fresh)
  rescue BBS::HTTP::Error, FeedXml::Unreadable => e
    BBS.log('feed', "#{feed.name}: #{e.class}: #{e.message}")
    nil
  end
end
