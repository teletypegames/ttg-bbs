# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  def catalog = Fixtures.catalog

  def tng = catalog.series.first

  def test_episodes_come_by_season_and_number
    assert_equal ['S1E01 Encounter at Farpoint', 'S1E03 The Naked Now', "S3E15 Yesterday's Enterprise"],
                 catalog.episodes(tng).map(&:label)
  end

  def test_seasons_group_the_episodes
    assert_equal([[1, 2], [3, 1]], catalog.seasons(tng).map { |season, eps| [season, eps.size] })
  end

  def test_a_film_is_labelled_by_its_year
    films = catalog.series.last
    assert films.films?
    assert_equal ['1982 Star Trek II: The Wrath of Khan'], catalog.episodes(films).map(&:label)
  end

  def test_on_this_day_finds_the_month_and_day_of_any_year
    found = catalog.on_this_day(Date.new(2026, 2, 19))
    assert_equal([["Yesterday's Enterprise", 'Q16290']], found.map { |e, s| [e.title, s.id] })
    assert_empty catalog.on_this_day(Date.new(2026, 2, 20))
  end

  def test_series_years_and_short_title
    assert_equal '1987–1994', tng.years
    assert_equal 'The Next Generation', tng.short_title
    assert_equal %w[TNG Film], catalog.series.map(&:abbreviation)
  end
end
