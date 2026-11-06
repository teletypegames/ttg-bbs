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
    Rubbs::Common::Storage::Snapshot.write(path('seed.json.gz'), { 'games' => RECORDS }, at)
    CatalogService.snapshot(seed: path('seed.json.gz'), path: path('catalog.json.gz'))
  end

  def service(wikidata: nil, at: Time.now)
    CatalogService.new(snapshot(at), wikidata: wikidata, ttl: 60)
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
    assert_raises(Rubbs::Common::Web::HTTP::Error) { service(wikidata: wikidata(error: Rubbs::Common::Web::HTTP::Error.new('timeout')), at: stale).refresh_if_stale }
    s = service(wikidata: wikidata(records: []), at: stale)
    assert_raises(CatalogService::EmptyCatalog) { s.refresh_if_stale }
    assert_equal %w[Q1 Q2 Q3], s.games.map(&:id)
    refute File.exist?(path('catalog.json.gz'))
  end

  def test_the_board_refreshes_in_the_background_unless_the_ttl_is_zero
    assert_equal [['catalog refresh', 3600]], jobs('604800')
    assert_empty jobs('0')
  end

  # The background jobs CommodexBBS#start begins with CATALOG_TTL set to +ttl+.
  def jobs(ttl)
    started = []
    ENV['COMMODEX_BBS_CATALOG_TTL'] = ttl
    board = CommodexBBS.new
    board.define_singleton_method(:services) { {} }
    Rubbs.stub(:background, ->(name, every:, **) { started << [name, every] }) { board.start }
    started
  ensure
    ENV.delete('COMMODEX_BBS_CATALOG_TTL')
  end
end
