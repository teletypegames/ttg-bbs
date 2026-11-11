# frozen_string_literal: true

require 'json'

# Wikidata (CC0) as a caller asks it, live: the search for films and for
# the people of the films (the Action API's full-text search, narrowed by
# statements), a film's page and a person's (wbgetentities, the names of
# what they point to in one more request), and a person's films (one SPARQL
# query). The Action API goes through rubbs' Rubbs::Common::Web::MediaWiki,
# RATE requests a second for all callers together. The answers are kept in a
# Rubbs::Common::Storage::Cache for TTL seconds. Failures go up as
# Rubbs::Common::Web::HTTP::Error.
class WikidataRepository
  ENDPOINT     = 'https://www.wikidata.org/w/api.php'
  USER_AGENT   = CatalogRepository::USER_AGENT
  RATE         = 5
  TTL          = 6 * 3600
  CACHE_SIZE   = 400
  CACHE_BYTES  = 32 * 1024 * 1024
  SEARCH_LIMIT = 30
  # The most films of a person's list.
  MAX_CREDITS  = 400
  # What a film is: a film, a feature, an animated, a television or a
  # documentary film.
  FILM_TYPES   = %w[Q11424 Q24869 Q202866 Q506240 Q93204].freeze
  # The trades of the people searched for: actor, film actor, director,
  # screenwriter, producer, composer, cinematographer.
  TRADES       = %w[Q33999 Q10800557 Q2526255 Q28389 Q3282637 Q36834 Q222344].freeze
  FILM_FILTER   = "haswbstatement:#{FILM_TYPES.map { |q| "P31=#{q}" }.join('|')}".freeze
  PERSON_FILTER = "haswbstatement:P31=Q5 haswbstatement:#{TRADES.map { |q| "P106=#{q}" }.join('|')}".freeze
  # The parts a person may have in a film, by property.
  PARTS = {
    'P57'  => 'director',
    'P58'  => 'writer',
    'P161' => 'cast',
    'P86'  => 'music',
    'P344' => 'camera',
    'P162' => 'producer'
  }.freeze

  def initialize(
    api: Rubbs::Common::Web::MediaWiki.new(endpoint: ENDPOINT, user_agent: USER_AGENT, name: 'Wikidata', rate: RATE),
    sparql: Rubbs::Common::Web::Wikidata.new(user_agent: USER_AGENT, pause: 0)
  )
    @api     = api
    @sparql  = sparql
    @answers = Rubbs::Common::Storage::Cache.new(
      ttl:         TTL,
      max_entries: CACHE_SIZE,
      max_bytes:   CACHE_BYTES,
      size:        ->(data) { JSON.generate(data).bytesize }
    )
  end

  # The films (HitModel) whose names hold +query+, the best first.
  def search_films(query) = search("#{query} #{FILM_FILTER}")

  # The people of the films (HitModel) whose names hold +query+.
  def search_people(query) = search("#{query} #{PERSON_FILTER}")

  # The FilmModel of +id+; nil when Wikidata has no such item.
  def film(id)
    entity = entity(id, 'labels|descriptions|claims|sitelinks')
    entity && FilmModel.from_entity(entity, names(FilmModel.references(entity)))
  end

  # The PersonModel of +id+ with their films; nil when there is no such
  # item.
  def person(id)
    entity = entity(id, 'labels|descriptions|claims|sitelinks')
    return nil unless entity

    place = PersonModel.birthplace_id(entity)
    PersonModel.from_entity(entity, birthplace: place && names([place])[place], credits: credits(id))
  end

  private

  def search(text)
    data = cached(
      action:       'query',
      generator:    'search',
      gsrsearch:    text,
      gsrlimit:     SEARCH_LIMIT,
      gsrnamespace: 0,
      prop:         'entityterms',
      wbetterms:    'label|description',
      wbetlanguage: 'en'
    )
    pages = Array(data.dig('query', 'pages')).sort_by { |page| page['index'].to_i }
    known = names(pages.map { |page| page['title'] })
    pages.map { |page| HitModel.from_api(page, known[page['title']]) }
  end

  # The entity +id+ (labels in English, Hungarian and mul, the English and
  # Hungarian articles), or nil.
  def entity(id, props)
    return nil unless id.to_s.match?(/\AQ\d+\z/)

    data   = cached(action: 'wbgetentities', ids: id, props: props, languages: 'en|hu|mul', sitefilter: 'enwiki|huwiki')
    entity = data.dig('entities', id)
    entity unless entity.nil? || entity.key?('missing')
  end

  # { id => name } of +ids+, fifty a request.
  def names(ids)
    ids.each_slice(50).with_object({}) do |slice, all|
      data = cached(action: 'wbgetentities', ids: slice.join('|'), props: 'labels', languages: 'en|mul|hu')
      (data['entities'] || {}).each do |id, entity|
        name = FilmModel.label(entity, %w[en mul hu])
        all[id] = name if name
      end
    end
  end

  # The films of person +id+, the newest first, each with their parts.
  def credits(id)
    rows  = @answers.fetch([:credits, id]) { @sparql.select(credits_query(id)) }
    films = rows.each_with_object({}) { |row, all| credit_row(all, row) }
    films.map { |film, e| CreditModel.new(film, e[:title], e[:year], e[:parts].sort_by { |p| PARTS.values.index(p) }.freeze) }
      .sort_by { |c| [-(c.year || 0), c.title] }
  end

  # Adds the film and the part of a credits +row+ to +all+.
  def credit_row(all, row)
    film  = Rubbs::Common::Web::Wikidata.qid(row['film'])
    title = Rubbs::Common::Web::Wikidata.text(row['filmLabel'])
    return if film.nil? || title.empty? || title.match?(/\AQ\d+\z/)

    entry = all[film] ||= { title: title, year: row.dig('date', 'value').to_s[/\A-?(\d{4})/, 1]&.to_i, parts: [] }
    part  = PARTS[row.dig('p', 'value').to_s[/P\d+\z/]]
    entry[:parts] << part if part && !entry[:parts].include?(part)
  end

  def credits_query(id)
    <<~SPARQL
      SELECT ?film ?filmLabel ?p (MIN(?d) AS ?date) WHERE {
        VALUES ?p { #{PARTS.keys.map { |p| "wdt:#{p}" }.join(' ')} }
        ?film ?p wd:#{id} . ?film wdt:P31/wdt:P279* wd:Q11424 .
        OPTIONAL { ?film wdt:P577 ?d . }
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en,mul". }
      } GROUP BY ?film ?filmLabel ?p LIMIT #{MAX_CREDITS}
    SPARQL
  end

  def cached(**params) = @answers.fetch(params) { @api.get(**params) }
end
