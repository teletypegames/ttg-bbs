# frozen_string_literal: true

require 'uri'

# The Commodore 64 games of Wikidata (CC0), read from its SPARQL endpoint:
# every item on the platform Commodore 64 (P400 = Q99775) that is a video
# game (P31/P279* Q7889). One query for the items, their labels and English
# Wikipedia articles, then one per property, merged here into the records of
# the catalog file, with rubbs' BBS::Wikidata (a deadline, a body cap, a
# pause before each query). Any failed query raises (BBS::HTTP::Error, or
# Error for an error status or an answer that is no JSON),
# so a refresh never leaves a half catalog. The names are cleaned of control
# characters.
class WikidataRepository
  # Wikidata answered an error status or no JSON.
  Error = BBS::Wikidata::Error

  USER_AGENT   = 'CommodexBBS/0.1 (Commodex BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
                 'https://git.teletypegames.org/bbs/commodex-bbs)'
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

  def initialize(pause: 1, client: BBS::Wikidata.new(user_agent: USER_AGENT, pause: pause))
    @client = client
  end

  # The records of every game, sorted by title.
  def records
    games = items
    years(games)
    PROPERTIES.each { |key, property| values(games, key, property) }
    games.values.sort_by { |g| [g['t'].downcase, g['id'][1..].to_i] }
  end

  private

  def items
    select(ITEMS).each_with_object({}) do |row, games|
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
    dates(select(DATES), games).each { |id, d| games[id]['y'] = (d[:c64].empty? ? d[:any] : d[:c64]).min }
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
    select("SELECT ?item ?v ?vLabel WHERE { #{GAMES} ?item wdt:#{property} ?v . #{LABELS} }").each do |row|
      game = games[qid(row['item'])]
      name = clean(key, row.dig('vLabel', 'value'))
      next if game.nil? || name.empty? || name.match?(/\AQ\d+\z/)

      list = game[key] ||= []
      list << name unless list.include?(name)
    end
    games.each_value { |g| g[key]&.sort_by!(&:downcase) }
  end

  # A game mode reads "single-player", not "single-player video game".
  def clean(key, name)
    name = text(name)
    key == 'mod' ? name.sub(/ video game\z/, '') : name
  end

  def text(value) = BBS::Text.line(value)

  def qid(binding) = BBS::Wikidata.qid(binding)

  def select(query) = @client.select(query)
end
