# frozen_string_literal: true

require 'json'
require 'uri'

# The Commodore 64 games of Wikidata (CC0), read from its SPARQL endpoint:
# every item on the platform Commodore 64 (P400 = Q99775) that is a video
# game (P31/P279* Q7889). One query for the items, their labels and English
# Wikipedia articles, then one per property, merged here into the records of
# the catalog file, over BBS::HTTP (a deadline, a body cap). Any failed
# query gives nil, so a refresh never leaves a half catalog. The names are
# cleaned of control characters.
class WikidataRepository
  ENDPOINT     = 'https://query.wikidata.org/sparql'
  USER_AGENT   = 'CommodexBBS/0.1 (Commodex BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
                 'https://git.teletypegames.org/bbs/commodex-bbs)'
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 90
  DEADLINE     = 180
  MAX_BYTES    = 32 * 1024 * 1024
  LANGUAGES    = 'en,mul,de,fr,it,es,nl,sv,pl,hu,ja'
  GAMES        = '?item wdt:P400 wd:Q99775 . ?item wdt:P31/wdt:P279* wd:Q7889 .'
  LABELS       = "SERVICE wikibase:label { bd:serviceParam wikibase:language \"#{LANGUAGES}\". }".freeze

  # The list fields of a record and the Wikidata properties they come from.
  PROPERTIES = { 'pub' => 'P123', 'dev' => 'P178', 'des' => 'P287', 'mus' => 'P86', 'gen' => 'P136',
                 'mod' => 'P404', 'ser' => 'P179' }.freeze

  ITEMS = <<~SPARQL.freeze
    SELECT ?item ?itemLabel ?article WHERE {
      #{GAMES}
      OPTIONAL { ?article schema:about ?item ; schema:isPartOf <https://en.wikipedia.org/> . }
      #{LABELS}
    }
  SPARQL

  DATES = <<~SPARQL.freeze
    SELECT ?item ?date ?platform WHERE {
      #{GAMES}
      ?item p:P577 ?statement . ?statement ps:P577 ?date .
      OPTIONAL { ?statement pq:P400 ?platform . }
    }
  SPARQL

  C64 = 'Q99775'

  def initialize(endpoint: ENDPOINT, pause: 1)
    @endpoint = endpoint
    @pause    = pause
  end

  # The records of every game, sorted by title; nil when a query failed.
  def records
    games = items or return nil
    years(games) or return nil
    PROPERTIES.each { |key, property| values(games, key, property) or return nil }
    games.values.sort_by { |g| [g['t'].downcase, g['id'][1..].to_i] }
  end

  private

  def items
    rows = select(ITEMS) or return nil
    rows.each_with_object({}) do |row, games|
      id    = qid(row['item'])
      title = text(row.dig('itemLabel', 'value'))
      next if id.nil? || title.empty? || title.match?(/\AQ\d+\z/)

      game = games[id] ||= { 'id' => id, 't' => title }
      article = row.dig('article', 'value')
      game['w'] ||= URI.decode_www_form_component(article.split('/wiki/', 2).last).tr('_', ' ') if article
    end
  end

  # The first year of each game: the earliest date given for the C64, else
  # the earliest at all.
  def years(games)
    rows = select(DATES) or return nil
    dates(rows, games).each { |id, d| games[id]['y'] = (d[:c64].empty? ? d[:any] : d[:c64]).min }
    true
  end

  # The years given for each game: { id => { c64: [...], any: [...] } }.
  def dates(rows, games)
    rows.each_with_object(Hash.new { |h, k| h[k] = { c64: [], any: [] } }) do |row, dates|
      id   = qid(row['item'])
      year = row.dig('date', 'value').to_s[/\A-?\d{4}/]&.to_i
      next unless games.key?(id) && year&.positive?

      dates[id][:any] << year
      dates[id][:c64] << year if qid(row['platform']) == C64
    end
  end

  def values(games, key, property)
    rows = select("SELECT ?item ?v ?vLabel WHERE { #{GAMES} ?item wdt:#{property} ?v . #{LABELS} }") or return nil
    rows.each do |row|
      game = games[qid(row['item'])]
      name = clean(key, row.dig('vLabel', 'value'))
      next if game.nil? || name.empty? || name.match?(/\AQ\d+\z/)

      list = game[key] ||= []
      list << name unless list.include?(name)
    end
    games.each_value { |g| g[key]&.sort_by!(&:downcase) }
    true
  end

  # A game mode reads "single-player", not "single-player video game".
  def clean(key, name)
    name = text(name)
    key == 'mod' ? name.sub(/ video game\z/, '') : name
  end

  def text(value) = BBS::Text.clean(value.to_s, keep_newlines: false).strip

  def qid(binding) = binding&.dig('value').to_s[%r{/entity/(Q\d+)\z}, 1]

  def select(query)
    sleep @pause
    response = BBS::HTTP.post(@endpoint, body: URI.encode_www_form(query: query), user_agent: USER_AGENT,
                                         headers: { 'Accept' => 'application/sparql-results+json',
                                                    'Content-Type' => 'application/x-www-form-urlencoded' },
                                         open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT,
                                         deadline: DEADLINE, max_bytes: MAX_BYTES)
    return JSON.parse(BBS::Text.utf8(response.body)).dig('results', 'bindings') if response.ok?

    warn "commodex-bbs: Wikidata answered #{response.status}"
    nil
  rescue StandardError => e
    warn "commodex-bbs: Wikidata: #{e.class}: #{e.message}"
    nil
  end
end
