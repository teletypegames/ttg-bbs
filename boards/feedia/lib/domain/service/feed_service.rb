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
    channel = @feeds.read(feed, fresh: fresh)
    Rubbs.achieve(:feed, ref: feed.name.to_s) if channel
    channel
  rescue Rubbs::Common::Web::HTTP::Error, FeedXml::Unreadable => e
    Rubbs.log('feed', "#{feed.name}: #{e.class}: #{e.message}")
    nil
  end
end
