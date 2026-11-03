# frozen_string_literal: true

require 'json'

# Memory Alpha's Action API (memory-alpha.fandom.com, CC BY-NC), anonymously,
# through rubbs' BBS::MediaWiki (three requests a second, all callers
# together): a full-text search, an article as plain text, a random title.
# The answers are kept in a BBS::Cache, bounded in entries and in bytes (of
# their JSON), for TTL seconds. Failures go up as BBS::HTTP::Error.
class MemoryAlphaRepository
  ENDPOINT     = 'https://memory-alpha.fandom.com/api.php'
  USER_AGENT   = WikidataRepository::USER_AGENT
  RATE         = 3
  TTL          = 1800
  CACHE_SIZE   = 300
  CACHE_BYTES  = 24 * 1024 * 1024
  SEARCH_LIMIT = 30

  def initialize(client: BBS::MediaWiki.new(endpoint: ENDPOINT, user_agent: USER_AGENT, name: 'Memory Alpha', rate: RATE))
    @client  = client
    @answers = BBS::Cache.new(ttl: TTL, max_entries: CACHE_SIZE, max_bytes: CACHE_BYTES,
                              size: ->(data) { JSON.generate(data).bytesize })
  end

  # The SearchResultModels for +query+, best first.
  def search(query)
    data = cached(action: 'query', list: 'search', srsearch: query, srlimit: SEARCH_LIMIT, srnamespace: 0,
                  srprop: 'wordcount')
    (data.dig('query', 'search') || []).map { |hit| SearchResultModel.from_api(hit) }
  end

  # The ArticleModel titled +title+ (redirects followed); nil when it is
  # missing.
  def article(title)
    ArticleModel.from_api(cached(action: 'query', prop: 'extracts|info', explaintext: 1, exsectionformat: 'wiki',
                                 redirects: 1, inprop: 'url', titles: title))
  end

  # A random article's title, or nil.
  def random_title
    data = @client.get(action: 'query', list: 'random', rnnamespace: 0, rnlimit: 1)
    data.dig('query', 'random', 0, 'title')&.then { |title| BBS::Text.line(title) }
  end

  private

  def cached(**params) = @answers.fetch(params) { @client.get(**params) }
end
