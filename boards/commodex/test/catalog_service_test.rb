# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  # A snapshot that is as old as the test says.
  class Repository
    attr_reader :snapshot, :replaced

    def initialize(games, at: Time.now)
      @snapshot = CatalogRepository::Snapshot.new(games: games.freeze, generated_at: at)
      @replaced = []
    end

    def replace(records) = @replaced << records
  end

  GAMES = [game('Q1', 'Zork', 'y' => 1982, 'gen' => ['adventure'], 'pub' => ['Infocom']),
           game('Q2', 'Élite', 'y' => 1985, 'gen' => ['space'], 'dev' => ['Acornsoft']),
           game('Q3', 'Zork II', 'y' => 1982, 'gen' => ['adventure'])].freeze

  def service(wikidata: nil, at: Time.now)
    CatalogService.new(Repository.new(GAMES, at: at), wikidata: wikidata, ttl: 60, retry_after: 0)
  end

  def test_search_folds_and_puts_the_starts_first
    assert_equal %w[Q1 Q3], service.search('zork').map(&:id)
    assert_equal %w[Q2], service.search('ELITE').map(&:id)
    assert_equal :too_short, service.search('z')
  end

  def test_browse_by_year_genre_and_company
    s = service
    assert_equal [[1982, 2], [1985, 1]], s.years
    assert_equal [['adventure', 2], ['space', 1]], s.genres
    assert_equal [['a', 1], ['i', 1]], s.letters
    assert_equal %w[Q1], s.of_company('Infocom').map(&:id)
  end

  def test_a_round_that_raises_is_logged_and_the_thread_goes_on
    wikidata = Object.new
    def wikidata.records = raise(IOError, 'socket closed')
    s = service(wikidata: wikidata, at: Time.now - 3600)
    _, err = capture_io { s.refresh_round }
    assert_match(/commodex-bbs: catalog refresh: IOError/, err)
  end

  def test_a_failed_refresh_keeps_the_old_snapshot
    wikidata = Object.new
    def wikidata.records = nil
    assert_equal :failed, service(wikidata: wikidata).refresh!
  end
end
