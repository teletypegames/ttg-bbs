# frozen_string_literal: true

require 'uri'

# The franchise's series, episodes and films from Wikidata (CC0), read with
# rubbs' Rubbs::Common::Web::Wikidata: every item that is a Star Trek episode (Q61220733)
# with the series it is part of (P179), its season (P4908) and numbers, and
# every film of the franchise (P8345 = Q1092) that is no episode and has a
# Memory Alpha article. One query for the items, then one each for the
# dates, the directors and the writers, merged here into the records of the
# catalog file. Any failed query raises (Rubbs::Common::Web::HTTP::Error), so a refresh
# never leaves a half catalog.
#
# A record has short keys: series { id t s e ma }, episodes { id t se sn n o
# d dir wr ma }; the films are the episodes of the series "films".
class WikidataRepository
  USER_AGENT = 'StarbaseBBS/0.1 (Starbase BBS, Teletype Games telnet BBS; https://teletypegames.org; ' \
               'https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/starbase)'
  EPISODES   = '?item wdt:P31 wd:Q61220733 .'
  FILMS      = '?item wdt:P31 wd:Q11424 ; wdt:P8345 wd:Q1092 . FILTER NOT EXISTS { ?item wdt:P31 wd:Q61220733 }'
  LABELS     = 'SERVICE wikibase:label { bd:serviceParam wikibase:language "en,mul". }'
  ALPHA      = '?item wdt:P6262 ?ma . FILTER(STRSTARTS(?ma, "memory-alpha:"))'
  # Fewer episodes than this make no series: a stray item.
  MIN_EPISODES = 3

  ITEMS = <<~SPARQL.freeze
    SELECT ?item ?itemLabel ?series ?ord ?sn ?n ?ma WHERE {
      #{EPISODES}
      ?item p:P179 ?part . ?part ps:P179 ?series .
      OPTIONAL { ?part pq:P1545 ?ord . }
      OPTIONAL { ?item p:P4908 ?in . ?in ps:P4908 ?season .
                 OPTIONAL { ?in pq:P1545 ?n . } OPTIONAL { ?season p:P179/pq:P1545 ?sn . } }
      OPTIONAL { #{ALPHA} }
      #{LABELS}
    }
  SPARQL

  FILM_ITEMS = <<~SPARQL.freeze
    SELECT ?item ?itemLabel ?ma WHERE { #{FILMS} #{ALPHA} #{LABELS} }
  SPARQL

  def initialize(client: Rubbs::Common::Web::Wikidata.new(user_agent: USER_AGENT))
    @client = client
  end

  # The catalog: { 'series' => [...], 'episodes' => [...] }, the series by
  # their first year, the films last.
  def records
    episodes = items
    films    = film_items
    every    = episodes.merge(films)
    details(every)
    series = series_of(episodes)
    { 'series' => series + [films_series(films)], 'episodes' => every.values.select { |e| keep?(e, series) } }
  end

  private

  def items
    @client.select(ITEMS).each_with_object({}) do |row, all|
      record = entry(all, row) or next
      record['se'] ||= Rubbs::Common::Web::Wikidata.qid(row['series'])
      %w[ord o sn sn n n].each_slice(2) { |var, key| record[key] ||= number(row[var]) }
    end
  end

  def film_items
    @client.select(FILM_ITEMS).each_with_object({}) { |row, all| entry(all, row)&.store('se', SeriesModel::FILMS) }
  end

  # The record of +row+'s item in +all+, made on first sight, with the
  # Memory Alpha title the row brings; nil for an item without a name.
  def entry(all, row)
    id    = Rubbs::Common::Web::Wikidata.qid(row['item'])
    title = Rubbs::Common::Web::Wikidata.text(row['itemLabel'])
    return nil if id.nil? || title.empty? || title.match?(/\AQ\d+\z/)

    record = all[id] ||= { 'id' => id, 't' => title }
    alpha  = alpha_title(row['ma'])
    record['ma'] = better(record['ma'], alpha) if alpha
    record
  end

  # The first air date, the directors and the writers of every record.
  def details(all)
    [EPISODES, FILMS].each do |items|
      dates(all, items)
      { 'dir' => 'P57', 'wr' => 'P58' }.each { |key, property| people(all, items, key, property) }
    end
  end

  def dates(all, items)
    @client.select("SELECT ?item ?date WHERE { #{items} ?item wdt:P577 ?date . }").each do |row|
      record = all[Rubbs::Common::Web::Wikidata.qid(row['item'])]
      day    = row.dig('date', 'value').to_s[/\A\d{4}-\d\d-\d\d/]
      record['d'] = [record['d'], day].compact.min if record && day
    end
  end

  def people(all, items, key, property)
    @client.select("SELECT ?item ?v ?vLabel WHERE { #{items} ?item wdt:#{property} ?v . #{LABELS} }").each do |row|
      record = all[Rubbs::Common::Web::Wikidata.qid(row['item'])]
      name   = Rubbs::Common::Web::Wikidata.text(row['vLabel'])
      next if record.nil? || name.empty? || name.match?(/\AQ\d+\z/)

      list = record[key] ||= []
      list << name unless list.include?(name)
    end
  end

  # The series with enough episodes, with their names, years and articles.
  def series_of(episodes)
    ids = episodes.each_value.map { |e| e['se'] }.tally.select { |_, n| n >= MIN_EPISODES }.keys
    return [] if ids.empty?

    list = series_rows(ids).each_with_object({}) { |row, all| years(entry(all, row), row) }.values
    list.each { |s| s['s'] ||= first_year(episodes, s['id']) }
    list.sort_by { |s| [s['s'] || 9999, s['t']] }
  end

  def series_rows(ids)
    @client.select("SELECT ?item ?itemLabel ?start ?end ?ma WHERE { VALUES ?item { #{ids.map { |id| "wd:#{id}" }.join(' ')} } " \
                   'OPTIONAL { ?item wdt:P580 ?start . } OPTIONAL { ?item wdt:P582 ?end . } ' \
                   "OPTIONAL { #{ALPHA} } #{LABELS} }")
  end

  def years(record, row)
    return unless record

    { 's' => 'start', 'e' => 'end' }.each do |key, var|
      year = row.dig(var, 'value').to_s[/\A\d{4}/]&.to_i
      record[key] = [record[key], year].compact.send(key == 's' ? :min : :max) if year
    end
  end

  def first_year(episodes, series_id)
    episodes.each_value.filter_map { |e| e['d']&.to_i if e['se'] == series_id }.min
  end

  def films_series(films)
    years = films.each_value.filter_map { |f| f['d']&.to_i }
    { 'id' => SeriesModel::FILMS, 't' => 'The films', 's' => years.min, 'e' => years.max }
  end

  def keep?(record, series)
    record['se'] == SeriesModel::FILMS ? record['ma'] : series.any? { |s| s['id'] == record['se'] }
  end

  # The article title of a Fandom article id "memory-alpha:The_Cage_(episode)".
  def alpha_title(binding)
    value = binding&.dig('value').to_s
    return nil unless value.start_with?('memory-alpha:')

    Rubbs::Common::Text.line(URI.decode_www_form_component(value.delete_prefix('memory-alpha:')).tr('_', ' '))
  end

  # Of two Memory Alpha titles, the one of the episode or film itself, else
  # the shorter.
  def better(old, new)
    return new if old.nil?

    [old, new].min_by { |t| [t.match?(/\((?:episode|film)\)\z/) ? 0 : 1, t.size] }
  end

  def number(binding)
    value = binding&.dig('value').to_s
    value.match?(/\A\d+\z/) ? value.to_i : nil
  end
end
