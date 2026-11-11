# frozen_string_literal: true

# The catalog file's films from Wikidata (CC0), read with rubbs'
# Rubbs::Common::Web::Wikidata: every film (Q11424) with an article on at
# least MIN_LINKS wikis, which is how well known it is. One query finds
# them; their titles, release dates, directors and genres come BATCH films
# a query, so no query runs long. The answers are merged here into the
# records of the catalog file. Any failed query raises
# (Rubbs::Common::Web::HTTP::Error), so a refresh never leaves a half
# catalog.
#
# A record has short keys: { id t hu y d l dir g }; d only when the day of
# the first release is known. The records come the best known first.
class CatalogRepository
  USER_AGENT = 'KinemaBBS/0.1 (Kinema BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
               'https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/kinema)'
  MIN_LINKS  = 30
  BATCH      = 400
  LABELS     = 'SERVICE wikibase:label { bd:serviceParam wikibase:language "en,mul". }'
  # The day precision of a Wikidata time.
  DAY = 11

  FILMS = 'SELECT ?item ?links WHERE { ?item wdt:P31 wd:Q11424 ; wikibase:sitelinks ?links . ' \
          "FILTER(?links >= #{MIN_LINKS}) }".freeze

  def initialize(client: Rubbs::Common::Web::Wikidata.new(user_agent: USER_AGENT))
    @client = client
  end

  # The catalog: { 'films' => [...] }, the best known first.
  def records
    films = found
    films.keys.each_slice(BATCH) do |ids|
      values = "VALUES ?item { #{ids.map { |id| "wd:#{id}" }.join(' ')} }"
      titles(films, values)
      dates(films, values)
      { 'dir' => 'P57', 'g' => 'P136' }.each { |key, property| names(films, values, key, property) }
    end
    { 'films' => films.values.select { |f| f['t'] }.sort_by { |f| [-f['l'], f['t']] } }
  end

  private

  # { id => record } of the films, each with its number of wikis.
  def found
    @client.select(FILMS).each_with_object({}) do |row, all|
      id = Rubbs::Common::Web::Wikidata.qid(row['item'])
      all[id] ||= { 'id' => id, 'l' => row.dig('links', 'value').to_i } if id
    end
  end

  # The English title (else the international one, else the Hungarian),
  # and the Hungarian one when it is another.
  def titles(all, values)
    query = "SELECT ?item ?l WHERE { #{values} ?item rdfs:label ?l . FILTER(LANG(?l) IN (\"en\", \"mul\", \"hu\")) }"
    labels(@client.select(query)).each do |id, by_language|
      record = all[id] or next
      hu = by_language['hu'] && FilmModel.bare_title(by_language['hu'])
      record['t'] = by_language['en'] || by_language['mul'] || hu
      record['hu'] = hu if hu && hu != record['t']
    end
  end

  # { id => { language => label } } of label +rows+.
  def labels(rows)
    rows.each_with_object(Hash.new { |h, k| h[k] = {} }) do |row, all|
      text = Rubbs::Common::Web::Wikidata.text(row['l'])
      all[Rubbs::Common::Web::Wikidata.qid(row['item'])][row.dig('l', 'xml:lang')] = text unless text.empty?
    end
  end

  # The earliest release of each film: its year, and its day when the
  # earliest is known to the day.
  def dates(all, values)
    query = "SELECT ?item ?date ?precision WHERE { #{values} ?item p:P577/psv:P577 ?value . " \
            '?value wikibase:timeValue ?date ; wikibase:timePrecision ?precision . }'
    @client.select(query).each do |row|
      record = all[Rubbs::Common::Web::Wikidata.qid(row['item'])]
      value  = row.dig('date', 'value').to_s
      year   = value[/\A-?(\d{4})/, 1]&.to_i
      next unless record && year

      earliest(record, year, row.dig('precision', 'value').to_i >= DAY ? value[/\A\d{4}-\d\d-\d\d/] : nil)
    end
  end

  # Keeps +year+ and +day+ in +record+ when they are earlier than what it
  # has; a year known to the day comes before the same year without one.
  def earliest(record, year, day)
    return if record['y'] && ([record['y'], record['d'] || '~'] <=> [year, day || '~']) <= 0

    record['y'] = year
    day ? record['d'] = day : record.delete('d')
  end

  def names(all, values, key, property)
    @client.select("SELECT ?item ?v ?vLabel WHERE { #{values} ?item wdt:#{property} ?v . #{LABELS} }").each do |row|
      record = all[Rubbs::Common::Web::Wikidata.qid(row['item'])]
      name   = Rubbs::Common::Web::Wikidata.text(row['vLabel'])
      next if record.nil? || name.empty? || name.match?(/\AQ\d+\z/)

      list = record[key] ||= []
      list << name unless list.include?(name) || list.size >= 4
    end
  end
end
