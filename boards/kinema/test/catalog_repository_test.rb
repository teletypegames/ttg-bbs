# frozen_string_literal: true

require 'test_helper'

class CatalogRepositoryTest < Minitest::Test
  # Answers each query by what it asks for, as SPARQL result rows.
  class Client
    def select(query)
      case query
      when /sitelinks/ then [row('Q1', links: '90'), row('Q2', links: '80'), row('Q3', links: '75')]
      when /rdfs:label/
        [row('Q1', l: %w[Casablanca en]), row('Q2', l: %w[Stalker en]), row('Q2', l: %w[Sztalker hu]),
         row('Q1', l: %w[Casablanca hu])]
      when /P577/
        [row('Q1', date: '1943-01-23T00:00:00Z', precision: '11'), row('Q1', date: '1942-11-26T00:00:00Z', precision: '11'),
         row('Q2', date: '1979-01-01T00:00:00Z', precision: '9'),
         row('Q2', date: '1979-05-25T00:00:00Z', precision: '11'), row('Q2', date: '1980-02-01T00:00:00Z', precision: '11')]
      when /P57 / then [row('Q2', vLabel: 'Andrei Tarkovsky')]
      when /P136/ then [row('Q2', vLabel: 'science fiction film'), row('Q2', vLabel: 'Q123')]
      else []
      end
    end

    def row(id, **values)
      { 'item' => { 'value' => "http://www.wikidata.org/entity/#{id}" } }.tap do |r|
        values.each do |k, v|
          r[k.to_s] = v.is_a?(Array) ? { 'value' => v[0], 'xml:lang' => v[1] } : { 'value' => v }
        end
      end
    end
  end

  def records = @records ||= CatalogRepository.new(client: Client.new).records['films']

  def test_the_films_with_a_title_the_best_known_first
    assert_equal([%w[Q1 Casablanca], %w[Q2 Stalker]], records.map { |f| f.values_at('id', 't') })
  end

  def test_the_hungarian_title_only_when_it_is_another
    assert_equal([nil, 'Sztalker'], records.map { |f| f['hu'] })
  end

  def test_the_earliest_release_and_its_day_only_when_known
    assert_equal([[1942, '1942-11-26'], [1979, '1979-05-25']], records.map { |f| f.values_at('y', 'd') })
  end

  def test_directors_and_genres_by_name
    stalker = records.last
    assert_equal [['Andrei Tarkovsky'], ['science fiction film']], stalker.values_at('dir', 'g')
  end
end
