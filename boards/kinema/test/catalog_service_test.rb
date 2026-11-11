# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  def catalog = Fixtures.catalog

  def test_the_film_of_the_day_is_the_same_all_day
    day = Date.new(2026, 11, 11)
    assert_equal catalog.film_of_the_day(day), catalog.film_of_the_day(day)
    assert_includes %w[Q1 Q2 Q3 Q4], catalog.film_of_the_day(day).id
  end

  def test_on_this_day_finds_the_month_and_day_of_any_year
    assert_equal ['Stalker'], catalog.on_this_day(Date.new(2026, 5, 25)).map(&:title)
    assert_empty catalog.on_this_day(Date.new(2026, 5, 26))
  end

  def test_decades_and_genres
    assert_equal [[1940, 1], [1970, 3]], catalog.decades
    assert_equal %w[Stalker Solaris Mirror], catalog.of_decade(1970).map(&:title)
    assert_equal [['drama', 3], ['science fiction', 2]], catalog.genres
    assert_equal ['romance'], Fixtures.catalog(genres: 1).genres.map(&:first) - ['drama', 'science fiction']
  end

  def test_the_search_reads_the_hungarian_titles_without_accents
    assert_equal ['Mirror'], catalog.search('tukor').map(&:title)
    assert_equal ['Stalker'], catalog.search('SZTALK').map(&:title)
    assert_equal :too_short, catalog.search('a')
  end

  def test_a_film_of_the_catalog
    stalker = catalog.find('Q2')
    assert_equal '1979 Stalker', stalker.label
    assert_equal 'Andrei Tarkovsky · science fiction, drama', stalker.note
  end
end
