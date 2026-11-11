# frozen_string_literal: true

# A film as its page shows it, read from Wikidata (wbgetentities) with the
# names of the people and things it points to: titles, the year and length,
# the people by their part (PersonRef: id and name), the genres,
# countries, languages, what it is based on, the films before and after
# it, the IMDb id and its Wikipedia articles (English and Hungarian
# titles).
FilmModel = Data.define(
  :id,
  :title,
  :hu_title,
  :description,
  :year,
  :minutes,
  :directors,
  :writers,
  :cast,
  :composers,
  :cinematographers,
  :producers,
  :genres,
  :countries,
  :languages,
  :based_on,
  :follows,
  :followed_by,
  :companies,
  :imdb,
  :enwiki,
  :huwiki
) do
  # Every item id +entity+ points to that a page names: those of PEOPLE and
  # THINGS.
  def self.references(entity)
    (FilmModel::PEOPLE + FilmModel::THINGS).flat_map { |_, property, count| ids(entity, property).first(count) }.uniq
  end

  # The film of a wbgetentities +entity+, with +names+ ({ id => name }) of
  # the items it points to.
  def self.from_entity(entity, names)
    new(
      id:          entity['id'].to_s,
      title:       label(entity, %w[en mul hu]) || entity['id'].to_s,
      hu_title:    label(entity, %w[hu])&.then { |t| bare_title(t) },
      description: Rubbs::Common::Text.line(entity.dig('descriptions', 'en', 'value')),
      year:        year(entity),
      minutes:     minutes(entity),
      **refs(entity, names),
      imdb:        values(entity, 'P345').first&.then { |v| v.to_s[/\Att\d+\z/] },
      enwiki:      entity.dig('sitelinks', 'enwiki', 'title'),
      huwiki:      entity.dig('sitelinks', 'huwiki', 'title')
    )
  end

  # { key => [PersonRef] } of the PEOPLE and THINGS of +entity+, those
  # without a name in +names+ left out.
  def self.refs(entity, names)
    (FilmModel::PEOPLE + FilmModel::THINGS).to_h do |key, property, count|
      [key, ids(entity, property).first(count).filter_map { |id| names[id]&.then { |n| PersonRef.new(id, n) } }.freeze]
    end
  end

  # The values of +property+'s statements, the preferred ones first and the
  # deprecated ones left out.
  def self.values(entity, property)
    claims = Array(entity.dig('claims', property)).reject { |c| c['rank'] == 'deprecated' }
    claims.sort_by { |c| c['rank'] == 'preferred' ? 0 : 1 }.filter_map { |c| c.dig('mainsnak', 'datavalue', 'value') }
  end

  def self.ids(entity, property) = values(entity, property).filter_map { |v| v['id'] if v.is_a?(Hash) }.uniq

  # A title without the note that tells it from another, as some
  # Hungarian labels have it: "Titanic (film, 1997)" is "Titanic".
  def self.bare_title(title) = title.sub(/\s*\((?:[^()]*\bfilm\b[^()]*|\d{4})\)\z/, '')

  def self.label(entity, languages)
    languages.each do |language|
      text = Rubbs::Common::Text.line(entity.dig('labels', language, 'value'))
      return text unless text.empty?
    end
    nil
  end

  def self.year(entity)
    values(entity, 'P577').filter_map { |v| v['time'].to_s[/\A\+(\d{4})/, 1]&.to_i if v.is_a?(Hash) }.min
  end

  def self.minutes(entity)
    amount = values(entity, 'P2047').find { |v| v.is_a?(Hash) && v['unit'].to_s.end_with?('/Q7727') }
    amount && amount['amount'].to_f.round
  end

  # "1979 Stalker".
  def label = [year, title].compact.join(' ')

  # The Hungarian title when it is another.
  def other_title = hu_title && hu_title != title ? hu_title : nil

  # Everyone in its credits, as [part, PersonRef], the director first.
  def credits
    FilmModel::PEOPLE.flat_map { |key, _, _| public_send(key).map { |person| [FilmModel::PARTS.fetch(key), person] } }
  end

  def wikipedia? = !(enwiki.nil? && huwiki.nil?)

  # The address of its English Wikipedia article, else the Hungarian.
  def wikipedia_url
    return "https://en.wikipedia.org/wiki/#{escape(enwiki)}" if enwiki

    "https://hu.wikipedia.org/wiki/#{escape(huwiki)}" if huwiki
  end

  def wikidata_url = "https://www.wikidata.org/wiki/#{id}"

  def imdb_url = imdb && "https://www.imdb.com/title/#{imdb}/"

  private

  # A title as Wikipedia writes it in an address: underscores, and only
  # what an address cannot hold escaped.
  def escape(title) = title.tr(' ', '_').gsub(%r{[^\w\-.~()!*',:/]}) { |c| c.bytes.map { |b| format('%%%02X', b) }.join }
end

# Someone or something a film points to: the Wikidata id and its name.
PersonRef = Data.define(:id, :name) do
  def to_s = name
end

class FilmModel
  # The parts of a film, by property: [key, Wikidata property, how many].
  PEOPLE = [[:directors, 'P57', 6], [:writers, 'P58', 8], [:cast, 'P161', 40], [:composers, 'P86', 4],
            [:cinematographers, 'P344', 4], [:producers, 'P162', 6]].freeze
  # The things it points to: [key, property, how many].
  THINGS = [[:genres, 'P136', 5], [:countries, 'P495', 4], [:languages, 'P364', 3], [:based_on, 'P144', 2],
            [:follows, 'P155', 1], [:followed_by, 'P156', 1], [:companies, 'P272', 3]].freeze

  # The name of each part in the credits.
  PARTS = {
    directors:        'director',
    writers:          'writer',
    cast:             'cast',
    composers:        'music',
    cinematographers: 'camera',
    producers:        'producer'
  }.freeze
end
