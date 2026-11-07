# frozen_string_literal: true

# What a caller can do with Wikipedia: look a title up (the article, or the
# search results when there is none), read an article, pick a random one,
# and switch between the configured languages. "Did not answer" is logged
# once here and comes back as nil, "nothing found" as an empty list.
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

    answer('search') { @wikipedia.search(query, lang: lang) }
  end

  # The ArticleModel titled +title+; nil when there is none or Wikipedia did
  # not answer.
  def article(title, lang:)
    found = answer('article') { @wikipedia.article(title, lang: lang) }
    Rubbs.achieve(:article, lang: lang.to_s, ref: title.to_s) if found
    found
  end

  # A random article's title, nil when Wikipedia did not answer.
  def random(lang:) = answer('random') { @wikipedia.random_title(lang: lang) }

  # What a caller typed: [article, nil] when there is an article of that
  # title (or one it redirects to), or a search hit of that title in
  # another case ("jack tramiel"), else [nil, the search results].
  def look_up(query, lang:)
    query = query.to_s.strip
    found = article(query, lang: lang) unless query.empty?
    return [found, nil] if found

    results = search(query, lang: lang)
    same    = results&.find { |hit| hit.title.casecmp?(query) }
    found   = article(same.title, lang: lang) if same
    found ? [found, nil] : [nil, results]
  end

  # The language after +lang+, round the list.
  def next_language(lang) = @languages[(@languages.index(lang).to_i + 1) % @languages.size]

  private

  # The block's value, or nil (logged) when Wikipedia did not answer or the
  # language is not one of the board's.
  def answer(what)
    yield
  rescue Rubbs::Common::Web::HTTP::Error, ArgumentError => e
    Rubbs.log('wikipedia', "#{what}: #{e.class}: #{e.message}")
    nil
  end
end
