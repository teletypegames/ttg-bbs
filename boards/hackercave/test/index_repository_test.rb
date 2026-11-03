# frozen_string_literal: true

require 'test_helper'

class IndexRepositoryTest < Minitest::Test
  include TempDir

  def test_import_counts_the_issued_rfcs_only
    repo = IndexRepository.new(path('index.sqlite3'))
    refute repo.ready?
    assert_equal 7, repo.import(File.join(FIXTURES, 'rfc-index.xml'))
    assert repo.ready?
    assert_equal 7, repo.count
  end

  def test_an_rfc_has_its_record
    rfc = index.rfc(854)
    assert_equal 'Telnet Protocol Specification', rfc.title
    assert_equal ['J. Postel', 'J.K. Reynolds'], rfc.author_list
    assert_equal 'May 1983', rfc.date_label
    assert_equal 15, rfc.pages
    assert_equal 'Internet Standard', rfc.status_label
    assert_equal "This RFC specifies a standard for the ARPA Internet community.\n\nHosts on the ARPA Internet " \
                 'are expected to adopt and implement this standard.', rfc.abstract
  end

  def test_entities_and_days_are_read
    repo = index
    assert_equal "AT&T/Neda's Efficient Short Remote Operations (ESRO) Protocol Specification Version 1.2",
                 repo.rfc(2188).title
    assert_equal '1 April 1990', repo.rfc(1149).date_label
  end

  def test_a_number_never_issued_is_known_but_not_issued
    rfc = index.rfc(14)
    refute rfc.issued?
    assert_nil index.rfc(99_999)
  end

  def test_relations_both_ways
    repo = index
    assert_equal([['obsoleted by', 9293]], repo.relations(793).map { |kind, r| [kind, r.number] })
    assert_equal([['obsoletes', 793]], repo.relations(9293).map { |kind, r| [kind, r.number] })
    assert_equal([['updated by', 2549]], repo.relations(1149).map { |kind, r| [kind, r.number] })
  end

  def test_series
    repo = index
    assert_equal ['STD 7'], repo.series_of(9293)
    assert_equal([['STD 7', 9293]], repo.series('STD').map { |label, r| [label, r.number] })
    assert_equal [2119], repo.series_members('BCP', 14).map(&:number)
  end

  def test_search_by_words_status_and_year
    repo = index
    assert_equal [1149, 2549].sort, repo.search(%w[avian]).map(&:number).sort
    assert_equal [854], repo.search(%w[tel spec]).map(&:number)
    assert_equal [9293, 854, 793], repo.search([], status: 'INTERNET STANDARD').map(&:number)
    assert_equal [2549], repo.search(%w[avian], year: 1999).map(&:number)
  end

  def test_iens_are_under_negative_numbers_and_apart
    repo = index
    assert_equal 7, repo.count
    assert_equal [-1, -4, -7, -137], repo.iens.map(&:number)
    ien = repo.rfc(-137)
    assert_equal ['IEN 137', 'On Holy Wars and a Plea for Peace', 'Cohen', '1 April 1980'],
                 [ien.name, ien.title, ien.authors, ien.date_label]
    assert ien.text?
    refute repo.rfc(-4).text?
    assert_equal 'rfc-editor.org/ien/ien4.pdf', repo.rfc(-4).url
  end

  def test_iens_are_searched_but_not_on_the_rfc_shelves
    repo = index
    assert_equal 'Issues in the Interconnection of Datagram Networks', repo.rfc(-1).title
    assert_equal [-137], repo.search(%w[holy wars]).map(&:number)
    refute_includes repo.newest(20).map(&:number), -137
  end

  def test_errata
    repo = index
    assert_equal({ total: 2, verified: 1 }, repo.errata_count(793))
    first = repo.errata(793).first
    assert_equal [1001, 'Verified', 'Technical', '3.9'], [first.id, first.status, first.type, first.section]
    assert_includes first.correct_text, "\nbut special allowance"
    assert_equal({ total: 0, verified: 0 }, repo.errata_count(854))
  end

  def test_formats
    assert index.rfc(793).text?
    refute index.rfc(854).text?
  end

  def test_of_month
    assert_equal [1149, 2549], index.of_month(4, limit: 10).map(&:number)
    assert_equal 2, index.month_count(9)
  end

  def test_shelves_of_status_decade_and_newest
    repo = index
    assert_equal ['INTERNET STANDARD', 3], repo.statuses.first
    assert_equal [[1980, 2], [1990, 4], [2020, 1]], repo.decades
    assert_equal [793, 854], repo.of_decade(1980, limit: 10).map(&:number)
    assert_equal [9293, 2549], repo.newest(2).map(&:number)
  end

  def test_a_failed_import_keeps_the_old_index
    repo = index
    File.write(path('broken.xml'), '<rfc-index><rfc-entry><doc-id>RFC1</doc-id>')
    assert_raises(StandardError) { repo.import(path('broken.xml')) }
    assert_equal 7, repo.count
    assert_equal 'Telnet Protocol Specification', repo.rfc(854).title
  end
end
