# frozen_string_literal: true

require 'rubbs/common/web/http'
require 'rubbs/common/storage/cache'

# The feeds themselves, over HTTP(S) (Rubbs::Common::Web::HTTP: public addresses only, a
# deadline, at most MAX_BYTES), read by FeedXml and kept for TTL seconds in
# a Rubbs::Common::Storage::Cache: callers opening the same feed at once share one fetch and
# one parse, so a crowd cannot build a crowd of XML trees. A network error
# (Rubbs::Common::Web::HTTP::Error, Rubbs::Common::Web::HTTP::TooLarge for a body over MAX_BYTES) or a
# body that is no feed (FeedXml::Unreadable) goes up, unless an older copy
# of the feed is kept: that one is served instead.
class FeedRepository
  USER_AGENT = 'FeediaBBS/0.1 (Feedia BBS, Teletype Games telnet RSS reader; https://git.teletypegames.org/bbs/feedia-bbs)'
  ACCEPT     = 'application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.5'
  TTL        = 600
  MAX_BYTES  = 1024 * 1024
  REDIRECTS  = 4
  # The channels kept: every feed of a long list, in a few megabytes.
  CACHE_ENTRIES = 200
  CACHE_BYTES   = 16 * 1024 * 1024

  def initialize(http: Rubbs::Common::Web::HTTP)
    @http  = http
    @cache = Rubbs::Common::Storage::Cache.new(
      ttl:         TTL,
      max_entries: CACHE_ENTRIES,
      max_bytes:   CACHE_BYTES,
      size:        ->(channel) { FeedRepository.bytes(channel) }
    )
  end

  # The bytes a ChannelModel holds, roughly: the text of its items.
  def self.bytes(channel)
    channel.items.sum { |item| item.title.bytesize + item.markdown.bytesize + item.link.to_s.bytesize }
  end

  # The ChannelModel of +feed+ (a FeedModel). With +fresh+ the kept copy is
  # dropped first.
  def read(feed, fresh: false)
    @cache.delete(feed.url) if fresh
    @cache.fetch(feed.url) { FeedXml.channel(feed, fetch(feed.url)) }
  end

  private

  # The body as it came, bytes: REXML reads the encoding from the XML
  # declaration.
  def fetch(url)
    response = @http.get(
      url,
      headers:    { 'Accept' => ACCEPT },
      max_bytes:  MAX_BYTES,
      redirects:  REDIRECTS,
      user_agent: USER_AGENT
    )
    raise Rubbs::Common::Web::HTTP::Error, "HTTP #{response.status}" unless response.ok?

    response.body
  end
end
