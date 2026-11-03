# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  include TmpData

  # Wikidata that answers +records+, or raises +error+.
  def wikidata(records: [], error: nil)
    Object.new.tap do |w|
      w.define_singleton_method(:records) { error ? raise(error) : records }
    end
  end

  RECORDS = [{ 'id' => 'Q1', 't' => 'Zork', 'y' => 1982, 'gen' => ['adventure'], 'pub' => ['Infocom'] },
             { 'id' => 'Q2', 't' => 'Élite', 'y' => 1985, 'gen' => ['space'], 'dev' => ['Acornsoft'] },
             { 'id' => 'Q3', 't' => 'Zork II', 'y' => 1982, 'gen' => ['adventure'] }].freeze

  # A catalog file of RECORDS written +at+, as the seed.
  def snapshot(at)
    BBS::Snapshot.write(path('seed.json.gz'), { 'games' => RECORDS }, at)
    CatalogService.snapshot(seed: path('seed.json.gz'), path: path('catalog.json.gz'))
  end

  def service(wikidata: nil, at: Time.now, retry_after: 0)
    CatalogService.new(snapshot(at), wikidata: wikidata, ttl: 60, retry_after: retry_after)
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

  def test_a_fresh_catalog_is_not_read_again
    s = service(wikidata: wikidata(error: IOError.new('not asked')))
    assert_equal :fresh, s.refresh_if_stale
  end

  def test_a_stale_catalog_is_replaced
    records = [{ 'id' => 'Q9', 't' => 'Uridium' }]
    s = service(wikidata: wikidata(records: records), at: Time.now - 3600)
    assert_equal :ok, s.refresh_if_stale
    assert_equal %w[Q9], s.games.map(&:id)
    assert File.exist?(path('catalog.json.gz'))
  end

  def test_a_failed_refresh_raises_and_keeps_the_old_snapshot
    stale = Time.now - 3600
    assert_raises(BBS::HTTP::Error) { service(wikidata: wikidata(error: BBS::HTTP::Error.new('timeout')), at: stale).refresh_if_stale }
    s = service(wikidata: wikidata(records: []), at: stale)
    assert_raises(CatalogService::EmptyCatalog) { s.refresh_if_stale }
    assert_equal %w[Q1 Q2 Q3], s.games.map(&:id)
    refute File.exist?(path('catalog.json.gz'))
  end

  def test_the_refresh_runs_in_the_background_and_retries
    calls = Queue.new
    flaky = Object.new
    flaky.define_singleton_method(:records) do
      calls << :asked
      calls.size == 1 ? raise(IOError, 'socket closed') : []
    end
    s = service(wikidata: flaky, at: Time.now - 3600, retry_after: 0.01)
    _, err = capture_io do
      thread = s.start_refresh
      sleep 0.01 until calls.size >= 2
      thread.kill
    end
    assert_match(/: catalog refresh: IOError: socket closed/, err)
  end
end
