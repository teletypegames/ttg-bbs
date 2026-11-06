# frozen_string_literal: true

require 'test_helper'

class WikidataRepositoryTest < Minitest::Test
  # Answers each query by what it asks for, as SPARQL result rows.
  class Client
    def select(query)
      case query
      when /\?sn \?n \?ma/ then episodes
      when /wd:Q11424/
        query.include?('P577') ? [row('Q9', date: '1982-06-04T00:00:00Z')] : [film]
      when /VALUES/ then [row('S1', label: 'Star Trek: Test', start: '1987-09-28T00:00:00Z', ma: 'memory-alpha:Star_Trek:_Test')]
      when /P577/ then [row('E1', date: '1988-01-01T00:00:00Z'), row('E1', date: '1987-10-05T00:00:00Z')]
      when /P57 / then [row('E1', vLabel: 'Corey Allen')]
      else []
      end
    end

    def episodes
      (1..3).map do |n|
        row(
          "E#{n}",
          label:  "Episode #{n}",
          series: 'S1',
          ord:    n.to_s,
          sn:     '1',
          n:      n.to_s,
          ma:     n == 1 ? 'memory-alpha:Episode_1' : nil
        )
      end + [row('E1', label: 'Episode 1', series: 'S1', ma: 'memory-alpha:Episode_1_(episode)'),
             row('X1', label: 'Stray', series: 'S2')]
    end

    def film = row('Q9', label: 'Star Trek II: The Wrath of Khan', ma: 'memory-alpha:Star_Trek_II:_The_Wrath_of_Khan')

    def row(id, **values)
      item = id.start_with?('Q') ? id : "Q#{id.bytes.sum}"
      { 'item' => { 'value' => "http://www.wikidata.org/entity/#{item}" } }.tap do |r|
        r['itemLabel'] = { 'value' => values[:label] } if values[:label]
        r['series'] = { 'value' => "http://www.wikidata.org/entity/Q#{values[:series].bytes.sum}" } if values[:series]
        values.except(:label, :series).each { |k, v| r[k.to_s] = { 'value' => v } if v }
      end
    end
  end

  def records = @records ||= WikidataRepository.new(client: Client.new).records

  def test_the_series_with_enough_episodes_and_the_films
    assert_equal(
      [['Star Trek: Test', 1987, 'Star Trek: Test'], ['The films', 1982, nil]],
      records['series'].map { |s| [s['t'], s['s'], s['ma']] }
    )
    refute(records['episodes'].any? { |e| e['t'] == 'Stray' })
  end

  def test_an_episode_takes_its_numbers_earliest_date_people_and_own_article
    first = records['episodes'].find { |e| e['t'] == 'Episode 1' }
    assert_equal [1, 1, 1, '1987-10-05', ['Corey Allen'], 'Episode 1 (episode)'],
                 first.values_at('sn', 'n', 'o', 'd', 'dir', 'ma')
  end

  def test_a_film_belongs_to_the_films
    film = records['episodes'].find { |e| e['se'] == SeriesModel::FILMS }
    assert_equal ['Star Trek II: The Wrath of Khan', '1982-06-04'], film.values_at('t', 'd')
  end
end
