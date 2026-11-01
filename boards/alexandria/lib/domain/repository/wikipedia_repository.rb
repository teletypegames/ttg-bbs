# frozen_string_literal: true

# Wikipedia's Action API, anonymously, through WikipediaClient: a full-text
# search, an article as plain text, a random title. The answers are kept in
# a BBS::Cache, bounded in entries and in bytes, for TTL seconds. A network
# or parse error is warned and comes back as nil.
class WikipediaRepository
  USER_AGENT   = 'AlexandriaBBS/0.1 (Alexandria BBS, Teletype Games telnet BBS; https://git.teletypegames.org/bbs/alexandria-bbs)'
  TTL          = 600
  CACHE_SIZE   = 200
  CACHE_BYTES  = 16 * 1024 * 1024
  SEARCH_LIMIT = 30

  # +languages+: the Wikipedias (by language code) this board may ask.
  def initialize(languages:, client: WikipediaClient.new(user_agent: USER_AGENT))
    @languages = languages
    @client    = client
    @answers   = BBS::Cache.new(ttl: TTL, max_entries: CACHE_SIZE, max_bytes: CACHE_BYTES)
  end

  # The SearchResultModels for +query+, best first; nil when Wikipedia did
  # not answer.
  def search(query, lang:)
    data = cached(lang, action: 'query', list: 'search', srsearch: query, srlimit: SEARCH_LIMIT,
                        srprop: 'snippet|wordcount')
    (data.dig('query', 'search') || []).map { |hit| SearchResultModel.from_api(hit) }
  rescue StandardError => e
    failed('search', e)
  end

  # The ArticleModel titled +title+ (redirects followed); nil when it is
  # missing or Wikipedia did not answer.
  def article(title, lang:)
    data = cached(lang, action: 'query', prop: 'extracts|info', explaintext: 1, exsectionformat: 'wiki',
                        redirects: 1, inprop: 'url', titles: title)
    ArticleModel.from_api(data, lang: lang)
  rescue StandardError => e
    failed('article', e)
  end

  # A random article's title; nil when Wikipedia did not answer.
  def random_title(lang:)
    data = JSON.parse(@client.get(known(lang), action: 'query', list: 'random', rnnamespace: 0, rnlimit: 1))
    data.dig('query', 'random', 0, 'title')&.then { |title| BBS::Text.clean(title, keep_newlines: false) }
  rescue StandardError => e
    failed('random', e)
  end

  private

  # The answer to +params+, parsed; the JSON text is what the cache keeps,
  # so its bytes are what it counts.
  def cached(lang, **params)
    JSON.parse(@answers.fetch([lang, params]) { @client.get(known(lang), **params) })
  end

  def known(lang)
    raise ArgumentError, "unknown language #{lang}" unless @languages.include?(lang)
    lang
  end

  def failed(what, error)
    warn "alexandria-bbs: Wikipedia #{what}: #{error.class}: #{error.message}"
    nil
  end
end
