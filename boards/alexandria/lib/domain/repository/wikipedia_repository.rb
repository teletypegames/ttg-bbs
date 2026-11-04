# frozen_string_literal: true

require 'json'

# Wikipedia's Action API, anonymously, through rubbs' BBS::Wikipedia (five
# requests a second, all callers together): a full-text search, an article
# as plain text, a random title. The answers are kept in a BBS::Cache,
# bounded in entries and in bytes (of their JSON), for TTL seconds.
# Failures go up as BBS::HTTP::Error; an unknown language is an
# ArgumentError.
class WikipediaRepository
  USER_AGENT   = 'AlexandriaBBS/0.1 (Alexandria BBS, Teletype Games telnet BBS; https://git.teletypegames.org/bbs/alexandria-bbs)'
  RATE         = 5
  TTL          = 600
  CACHE_SIZE   = 200
  CACHE_BYTES  = 16 * 1024 * 1024
  SEARCH_LIMIT = 30

  # +languages+: the Wikipedias (by language code) this board may ask.
  def initialize(languages:, client: BBS::Wikipedia.new(user_agent: USER_AGENT, rate: RATE))
    @languages = languages
    @client    = client
    @answers   = BBS::Cache.new(
      ttl:         TTL,
      max_entries: CACHE_SIZE,
      max_bytes:   CACHE_BYTES,
      size:        ->(data) { JSON.generate(data).bytesize }
    )
  end

  # The SearchResultModels for +query+, best first.
  def search(query, lang:)
    data = cached(
      lang,
      action:   'query',
      list:     'search',
      srsearch: query,
      srlimit:  SEARCH_LIMIT,
      srprop:   'snippet|wordcount'
    )
    (data.dig('query', 'search') || []).map { |hit| SearchResultModel.from_api(hit) }
  end

  # The ArticleModel titled +title+ (redirects followed); nil when it is
  # missing.
  def article(title, lang:)
    data = cached(
      lang,
      action:          'query',
      prop:            'extracts|info',
      explaintext:     1,
      exsectionformat: 'wiki',
      redirects:       1,
      inprop:          'url',
      titles:          title
    )
    ArticleModel.from_api(data, lang: lang)
  end

  # A random article's title, or nil.
  def random_title(lang:)
    data = @client.get(known(lang), action: 'query', list: 'random', rnnamespace: 0, rnlimit: 1)
    data.dig('query', 'random', 0, 'title')&.then { |title| BBS::Text.line(title) }
  end

  private

  def cached(lang, **params) = @answers.fetch([lang, params]) { @client.get(known(lang), **params) }

  def known(lang)
    raise ArgumentError, "unknown language #{lang}" unless @languages.include?(lang)

    lang
  end
end
