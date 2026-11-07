# frozen_string_literal: true

# Memory Alpha as a caller asks it: look a title up (the article, or the
# search results when there is none), read an article, the article of an
# episode, a random one. "Did not answer" is logged once here and comes
# back as nil, "nothing found" as an empty list.
class LibraryService
  def initialize(memory_alpha)
    @memory_alpha = memory_alpha
  end

  # The SearchResultModels for +query+, best first; [] for an empty query,
  # nil when Memory Alpha did not answer.
  def search(query)
    query = query.to_s.strip
    return [] if query.empty?

    answer('search') { @memory_alpha.search(query) }
  end

  # The ArticleModel titled +title+; nil when there is none or Memory Alpha
  # did not answer.
  def article(title)
    found = answer('article') { @memory_alpha.article(title) }
    Rubbs.achieve(:article, ref: title.to_s) if found
    found
  end

  # The article of +episode+: the one Wikidata names, else the one of its
  # title, else the first search hit for it; nil when there is none.
  def article_of(episode)
    (episode.ma && article(episode.ma)) || look_up(episode.title).first ||
      search(episode.title)&.first&.then { |hit| article(hit.title) }
  end

  # A random article's title, nil when Memory Alpha did not answer.
  def random = answer('random') { @memory_alpha.random_title }

  # What a caller typed: [article, nil] when there is an article of that
  # title (or one it redirects to), or a search hit of that title in
  # another case ("data"), else [nil, the search results].
  def look_up(query)
    query = query.to_s.strip
    found = article(query) unless query.empty?
    return [found, nil] if found

    results = search(query)
    same    = results&.find { |hit| hit.title.casecmp?(query) }
    found   = article(same.title) if same
    found ? [found, nil] : [nil, results]
  end

  private

  def answer(what)
    yield
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('memory-alpha', "#{what}: #{e.class}: #{e.message}")
    nil
  end
end
