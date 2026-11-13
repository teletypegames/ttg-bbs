# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  include TmpData

  # Wikidata that answers +records+, or raises +error+.
  def wikidata(records: [], error: nil)
    Object.new.tap { |w| w.define_singleton_method(:records) { error ? raise(error) : records } }
  end

  def test_the_sparse_machines_come_last
    assert_equal %w[Q1115919 Q99775 Q918232 Q832692 Q5], sample_catalog(@dir).machines.map(&:id)
  end

  def test_search_by_name_hungarian_name_maker_and_cpu
    c = sample_catalog(@dir)
    assert_equal %w[Q99775], c.search('commodore 64').map(&:id)
    assert_equal %w[Q832692], c.search('tvc').map(&:id)
    assert_equal %w[Q1115919 Q832692], c.search('z80').map(&:id)
    assert_equal %w[Q832692], c.search('videoton').map(&:id)
    assert_equal :too_short, c.search('c')
  end

  def test_the_name_itself_comes_before_longer_names
    assert_equal 'Commodore 64', sample_catalog(@dir).search('64').first.name
  end

  def test_shelves
    c = sample_catalog(@dir)
    assert_equal [['console', 1], ['home', 4]], c.kinds
    assert_equal [[1980, 2]], c.decades
    assert_equal %w[Q918232 Q99775], c.legends.map(&:id)
    assert_equal %w[Q832692], c.hungarian.map(&:id)
    assert_equal [['c', 1], ['v', 1]], c.letters
    assert_equal [['Zilog Z80', 2]], c.cpus.first(1)
  end

  def test_the_family_line_and_the_same_cpu
    c = sample_catalog(@dir)
    assert_equal %w[Q918232 Q99775 Q1115919], c.family(c.find('Q99775')).map(&:id)
    assert_equal %w[Q918232 Q99775 Q1115919], c.family(c.find('Q1115919')).map(&:id)
    assert_equal %w[Q832692], c.same_cpu(c.find('Q1115919')).map(&:id)
  end

  def test_views_count_for_the_most_viewed
    Rubbs::Test.database(MIGRATIONS)
    c = sample_catalog(@dir)
    2.times { c.viewed(c.find('Q99775')) }
    c.viewed(c.find('Q5'))
    assert_equal([%w[Q99775 2], %w[Q5 1]], c.most_viewed.map { |m, n| [m.id, n.to_s] })
  end

  def test_a_stale_catalog_is_replaced_and_a_failed_refresh_keeps_it
    records = [{ 'id' => 'Q9', 't' => 'Amiga 500' }]
    assert_equal :ok, sample_catalog(@dir, wikidata: wikidata(records: records), at: Time.now - 3600).refresh_if_stale
    Dir.mktmpdir do |dir|
      c = sample_catalog(dir, wikidata: wikidata(records: []), at: Time.now - 3600)
      assert_raises(CatalogService::EmptyCatalog) { c.refresh_if_stale }
      assert_equal 5, c.count
    end
    assert_equal :fresh, sample_catalog(@dir, wikidata: wikidata(error: IOError.new('not asked'))).refresh_if_stale
  end
end
