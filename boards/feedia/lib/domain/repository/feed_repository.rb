# frozen_string_literal: true

require 'net/http'
require 'uri'

# The feeds themselves, over HTTP(S): a feed is fetched (redirects followed,
# at most MAX_BYTES), read by FeedXml and kept for TTL seconds. Every
# request names the reader in its User-Agent. A network or parse error is
# warned and comes back as nil.
class FeedRepository
  USER_AGENT = 'FeediaBBS/0.1 (Feedia BBS, Teletype Games telnet RSS reader; https://git.teletypegames.org/bbs/feedia-bbs)'
  TTL        = 600
  MAX_BYTES  = 4 * 1024 * 1024
  REDIRECTS  = 4
  ACCEPT     = 'application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.5'

  def initialize
    @cache = {}
    @mu    = Mutex.new
  end

  # The ChannelModel of +feed+ (a FeedModel); nil when it could not be
  # fetched or read. With +fresh+ the cache is skipped.
  def read(feed, fresh: false)
    hit = @mu.synchronize { @cache[feed.url] }
    return hit[1] if hit && !fresh && Time.now - hit[0] < TTL

    channel = FeedXml.channel(feed, fetch(feed.url))
    @mu.synchronize { @cache[feed.url] = [Time.now, channel] }
    channel
  rescue StandardError => e
    warn "Feed error (#{feed.url}): #{e.class}: #{e.message}"
    nil
  end

  private

  def fetch(url, hops = REDIRECTS)
    uri  = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 15
    request = Net::HTTP::Get.new(uri.request_uri, 'User-Agent' => USER_AGENT, 'Accept' => ACCEPT)
    http.request(request) do |response|
      case response
      when Net::HTTPRedirection
        raise FeedXml::Unreadable, 'too many redirects' if hops.zero?

        return fetch(URI.join(url, response['location']).to_s, hops - 1)
      when Net::HTTPSuccess
        body = +''
        response.read_body do |chunk|
          body << chunk
          raise FeedXml::Unreadable, 'the feed is too big' if body.bytesize > MAX_BYTES
        end
        return body
      else
        raise FeedXml::Unreadable, "HTTP #{response.code}"
      end
    end
  end
end
