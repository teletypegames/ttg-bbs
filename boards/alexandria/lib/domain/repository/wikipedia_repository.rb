# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Wikipedia's Action API, anonymously: a full-text search, an article as
# plain text, a random title. Answers are cached for TTL seconds, and every
# request names the board in its User-Agent (Wikipedia may answer 403
# without it). A network or parse error is warned and comes back as nil.
class WikipediaRepository
  USER_AGENT = 'AlexandriaBBS/0.1 (Teletype Games telnet BBS; https://git.teletypegames.org/bbs/alexandria)'
  TTL = 600
  CACHE_SIZE = 200
  SEARCH_LIMIT = 30
  # All callers share one pace towards Wikipedia, so a crowd on the board
  # cannot get our address throttled there: at most RATE requests a second,
  # and a request that would wait longer than MAX_WAIT is not sent at all
  # (the caller sees "Wikipedia did not answer" and can try again).
  RATE     = 5
  MAX_WAIT = 3

  # +languages+: the Wikipedias (by language code) this board may ask.
  def initialize(languages:)
    @languages = languages
    @cache     = {}
    @mu        = Mutex.new
    @next_slot = 0.0
  end

  # The SearchResultModels for +query+, best first; nil when Wikipedia did
  # not answer.
  def search(query, lang:)
    cached([:search, lang, query.downcase]) do
      data = api(lang, action: 'query', list: 'search', srsearch: query, srlimit: SEARCH_LIMIT, srprop: 'snippet|wordcount')
      (data.dig('query', 'search') || []).map { |hit| SearchResultModel.from_api(hit) }
    end
  rescue StandardError => e
    warn "Wikipedia search error: #{e.class}: #{e.message}"
    nil
  end

  # The ArticleModel titled +title+ (redirects followed); nil when it is
  # missing or Wikipedia did not answer.
  def article(title, lang:)
    cached([:article, lang, title]) do
      data = api(lang, action: 'query', prop: 'extracts|info', explaintext: 1, exsectionformat: 'wiki',
                       redirects: 1, inprop: 'url', titles: title)
      ArticleModel.from_api(data, lang: lang)
    end
  rescue StandardError => e
    warn "Wikipedia article error: #{e.class}: #{e.message}"
    nil
  end

  # A random article's title; nil when Wikipedia did not answer.
  def random_title(lang:)
    data = api(lang, action: 'query', list: 'random', rnnamespace: 0, rnlimit: 1)
    data.dig('query', 'random', 0, 'title')
  rescue StandardError => e
    warn "Wikipedia random error: #{e.class}: #{e.message}"
    nil
  end

  private

  def api(lang, **params)
    raise ArgumentError, "unknown language #{lang}" unless @languages.include?(lang)

    pace
    uri = URI("https://#{lang}.wikipedia.org/w/api.php")
    uri.query = URI.encode_www_form(params.merge(format: 'json', formatversion: 2))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 15
    response = http.get(uri.request_uri, 'User-Agent' => USER_AGENT, 'Accept-Encoding' => 'identity')
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  # Waits for this request's turn; raises when the queue is longer than MAX_WAIT.
  def pace
    wait = @mu.synchronize do
      now  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      slot = [@next_slot, now].max
      raise 'busy: too many Wikipedia requests at once' if slot - now > MAX_WAIT

      @next_slot = slot + (1.0 / RATE)
      slot - now
    end
    sleep wait if wait.positive?
  end

  def cached(key)
    hit = @mu.synchronize { @cache[key] }
    return hit[1] if hit && Time.now - hit[0] < TTL

    value = yield
    @mu.synchronize do
      @cache.shift while @cache.size >= CACHE_SIZE
      @cache[key] = [Time.now, value]
    end
    value
  end
end
