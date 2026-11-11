# frozen_string_literal: true

# Wikidata and Wikipedia as a caller asks them: search films and people, a
# film's page, a person's, a film's article. "Did not answer" is logged
# once here and comes back as nil, "nothing found" as an empty list. When
# Wikidata's search does not answer, a film search looks in the catalog.
class FilmService
  def initialize(wikidata:, wikipedia:, catalog:)
    @wikidata  = wikidata
    @wikipedia = wikipedia
    @catalog   = catalog
  end

  # The HitModels of the films whose names hold +query+; [] for an empty
  # query; the catalog's films when Wikidata did not answer (nil when it
  # has none either).
  def search_films(query)
    query = query.to_s.strip
    return [] if query.empty?

    found = answer('wikidata', 'film search') { @wikidata.search_films(query) }
    return found if found

    local = @catalog.search(query)
    local.is_a?(Array) && local.any? ? local.map { |f| HitModel.from_catalog(f) } : nil
  end

  # The HitModels of the people whose names hold +query+; nil when Wikidata
  # did not answer.
  def search_people(query)
    query = query.to_s.strip
    return [] if query.empty?

    answer('wikidata', 'people search') { @wikidata.search_people(query) }
  end

  # The FilmModel of +id+; nil when there is none or Wikidata did not
  # answer. A film opened is the :film event.
  def film(id)
    found = answer('wikidata', "film #{id}") { @wikidata.film(id) }
    Rubbs.achieve(:film, ref: found.id, title: found.title) if found
    found
  end

  # The PersonModel of +id+; nil when there is none or Wikidata did not
  # answer.
  def person(id) = answer('wikidata', "person #{id}") { @wikidata.person(id) }

  # The Wikipedia article of +film+ in +language+ ('en' or 'hu'; the
  # English one when it has it, else the Hungarian, by default); nil when
  # it has none or Wikipedia did not answer.
  def article(film, language = nil)
    language ||= film.enwiki ? 'en' : 'hu'
    title = language == 'en' ? film.enwiki : film.huwiki
    title && answer('wikipedia', title) { @wikipedia.article(language, title) }
  end

  private

  def answer(source, what)
    yield
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log(source, "#{what}: #{e.class}: #{e.message}")
    nil
  end
end
