# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# Both faces on a fake line, over the fixture catalog, a Wikidata that
# answers from memory and the ratings in a database in memory.
class FacesTest < Minitest::Test
  Board = Struct.new(:services)

  # A FilmService stand-in: every film is Stalker, every search finds it.
  class Films
    def film(_id)
      entity = Fixtures.entity('stalker')
      names  = FilmModel.references(entity).to_h { |id| [id, "Name of #{id}"] }
      FilmModel.from_entity(entity, names.merge('Q853' => 'Andrei Tarkovsky'))
    end

    def search_films(_query) = [HitModel.new(id: 'Q200437', label: 'Stalker', note: '1979 film by Andrei Tarkovsky')]

    def search_people(_query) = []
  end

  def setup
    Rubbs::Test.database(MIGRATIONS)
    @board = Board.new({ catalog: Fixtures.catalog, films: Films.new, ratings: RatingService.new })
  end

  def plain(text) = text.gsub(/\e\[[\d;?]*[A-Za-z]/, '').gsub(/\s+/, ' ')

  def test_the_c64_menu_and_the_film_of_the_day
    session = Rubbs::Test::Session.new(petscii: true, keys: ['d', :enter, 'q', 'q'])
    UI::Petscii.new(session, {}, @board).run

    out = plain(session.output)
    assert_includes out, 'the film catalog on a telnet line'
    assert_includes out, 'Stalker'
    assert_includes out, 'hungarian title'
    assert_includes out, 'not rated yet'
  end

  def test_the_c64_search_finds_a_film
    session = Rubbs::Test::Session.new(petscii: true, keys: ['f', *'stalker'.chars, :enter, :enter, 'q', 'q', 'q', 'q'])
    UI::Petscii.new(session, {}, @board).run

    assert_includes plain(session.output), '163 min'
  end

  def test_a_guest_cannot_rate_on_the_c64
    session = Rubbs::Test::Session.new(petscii: true, keys: ['d', 'q', 'r', 's', :enter, 'q', 'q', 'q'])
    UI::Petscii.new(session, {}, @board).run

    assert_includes plain(session.output), 'log in or make an account first'
  end

  def test_the_desktop_opens_the_film_of_the_day
    before = Rubbs.config.board
    Rubbs.config.board = @board
    session = Rubbs::Test::Session.new(keys: [:alt_x])
    UI::Modern::APP.run(session: session, session_id: 'test')

    out = plain(session.output)
    assert_includes out, 'Stalker'
    assert_includes out, 'Andrei Tarkovsky'
  ensure
    Rubbs.config.board = before
  end
end
