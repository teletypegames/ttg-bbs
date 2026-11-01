# frozen_string_literal: true

# What a caller can do with Wikipedia: look a title up (the article, or the
# search results when there is none), read an article, pick a random one,
# and switch between the configured languages. "Did not answer" comes back
# as nil, "nothing found" as an empty list.
class ArticleService
  attr_reader :languages

  def initialize(wikipedia, languages:)
    @wikipedia = wikipedia
    @languages = languages
  end

  # The SearchResultModels for +query+, best first; [] for an empty query,
  # nil when Wikipedia did not answer.
  def search(query, lang:)
    query = query.to_s.strip
    return [] if query.empty?

    @wikipedia.search(query, lang: lang)
  end

  # The ArticleModel titled +title+; nil when there is none or Wikipedia did
  # not answer.
  def article(title, lang:) = @wikipedia.article(title, lang: lang)

  # A random article's title, nil when Wikipedia did not answer.
  def random(lang:) = @wikipedia.random_title(lang: lang)

  # What a caller typed: [article, nil] when there is an article of that
  # title (or one it redirects to), else [nil, the search results].
  def look_up(query, lang:)
    found = article(query.to_s.strip, lang: lang) unless query.to_s.strip.empty?
    found ? [found, nil] : [nil, search(query, lang: lang)]
  end

  # The language after +lang+, round the list.
  def next_language(lang) = @languages[(@languages.index(lang).to_i + 1) % @languages.size]
end
