# frozen_string_literal: true

require 'json'

# A Wikipedia article, English or Hungarian, as plain text through the
# Action API's extracts (rubbs' Rubbs::Common::Web::Wikipedia, RATE requests
# a second). The answers are kept for TTL seconds in a
# Rubbs::Common::Storage::Cache bounded in entries and in bytes. A failure
# goes up as Rubbs::Common::Web::HTTP::Error.
class WikipediaRepository
  TTL         = 86_400
  CACHE_SIZE  = 150
  CACHE_BYTES = 24 * 1024 * 1024
  RATE        = 5

  def initialize(client: Rubbs::Common::Web::Wikipedia.new(user_agent: CatalogRepository::USER_AGENT, rate: RATE))
    @client  = client
    @answers = Rubbs::Common::Storage::Cache.new(
      ttl:         TTL,
      max_entries: CACHE_SIZE,
      max_bytes:   CACHE_BYTES,
      size:        ->(data) { JSON.generate(data).bytesize }
    )
  end

  # The ArticleModel titled +title+ on the +language+ Wikipedia (redirects
  # followed); nil when it is missing.
  def article(language, title)
    data = @answers.fetch([language, title]) do
      @client.get(
        language,
        action:          'query',
        prop:            'extracts|info',
        explaintext:     1,
        exsectionformat: 'wiki',
        redirects:       1,
        inprop:          'url',
        titles:          title
      )
    end
    ArticleModel.from_api(language, data)
  end
end
