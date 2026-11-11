# frozen_string_literal: true

require 'test_helper'

class FilmModelTest < Minitest::Test
  def entity = Fixtures.entity('stalker')

  def film
    names = FilmModel.references(entity).to_h { |id| [id, "Name of #{id}"] }
    names['Q853'] = 'Andrei Tarkovsky'
    FilmModel.from_entity(entity, names)
  end

  def test_the_facts_of_a_film
    assert_equal ['Stalker', 'Sztalker', 1979, 163, 'tt0079944'],
                 [film.title, film.other_title, film.year, film.minutes, film.imdb]
    assert_equal ['Andrei Tarkovsky'], film.directors.map(&:name)
    assert_equal 3, film.cast.size
    assert_equal 'https://en.wikipedia.org/wiki/Stalker_(1979_film)', film.wikipedia_url
  end

  def test_the_credits_put_the_director_first_and_a_person_once_per_part
    parts = film.credits.map { |part, person| [part, person.id] }
    assert_equal %w[director Q853], parts.first
    assert_includes parts, %w[writer Q853]
    assert_equal(1, UI::Rows.people(film).count { |r| r.id == 'Q853' })
  end

  def test_an_item_it_points_to_without_a_name_is_left_out
    bare = FilmModel.from_entity(entity, {})
    assert_empty bare.directors
    assert_equal 'Stalker', bare.title
  end
end
