# frozen_string_literal: true

require 'test_helper'

class IndexTest < Minitest::Test
  include TempDir

  def test_import_counts_the_issued_rfcs_only
    refute RfcModel.ready?
    assert_equal 7, IndexBuilder.new.build(File.join(FIXTURES, 'rfc-index.xml'))
    assert RfcModel.ready?
    assert_equal 7, RfcModel.issued_count
  end

  def test_an_rfc_has_its_record
    index
    rfc = RfcModel.rfc(854)
    assert_equal 'Telnet Protocol Specification', rfc.title
    assert_equal ['J. Postel', 'J.K. Reynolds'], rfc.author_list
    assert_equal 'May 1983', rfc.date_label
    assert_equal 15, rfc.pages
    assert_equal 'Internet Standard', rfc.status_label
    assert_equal "This RFC specifies a standard for the ARPA Internet community.\n\nHosts on the ARPA Internet " \
                 'are expected to adopt and implement this standard.',
                 rfc.abstract
  end

  def test_entities_and_days_are_read
    index
    assert_equal "AT&T/Neda's Efficient Short Remote Operations (ESRO) Protocol Specification Version 1.2",
                 RfcModel.rfc(2188).title
    assert_equal '1 April 1990', RfcModel.rfc(1149).date_label
  end

  def test_a_number_never_issued_is_known_but_not_issued
    index
    rfc = RfcModel.rfc(14)
    refute rfc.issued?
    assert_equal '', rfc.title
    assert_nil RfcModel.rfc(99_999)
    assert_nil RfcModel.rfc('x')
  end

  def test_relations_both_ways
    index
    assert_equal([['obsoleted by', 9293]], RelationModel.of(793).map { |kind, r| [kind, r.number] })
    assert_equal([['obsoletes', 793]], RelationModel.of(9293).map { |kind, r| [kind, r.number] })
    assert_equal([['updated by', 2549]], RelationModel.of(1149).map { |kind, r| [kind, r.number] })
    assert_equal RfcModel.rfc(9293), RelationModel.of(793).first.last
  end

  def test_series
    index
    assert_equal ['STD 7'], SeriesModel.of(9293)
    assert_equal([['STD 7', 9293]], SeriesModel.rfcs('STD').map { |label, r| [label, r.number] })
    assert_equal [2119], SeriesModel.members_of('BCP', 14).map(&:number)
  end

  def test_search_by_words_status_and_year
    index
    assert_equal [1149, 2549].sort, RfcModel.search(%w[avian]).map(&:number).sort
    assert_equal [854], RfcModel.search(%w[tel spec]).map(&:number)
    assert_equal [9293, 854, 793], RfcModel.search([], status: 'INTERNET STANDARD').map(&:number)
    assert_equal [2549], RfcModel.search(%w[avian], year: 1999).map(&:number)
  end

  def test_iens_are_under_negative_numbers_and_apart
    index
    assert_equal 7, RfcModel.issued_count
    assert_equal [-1, -4, -7, -137], RfcModel.iens.map(&:number)
    ien = RfcModel.rfc(-137)
    assert_equal ['IEN 137', 'On Holy Wars and a Plea for Peace', 'Cohen', '1 April 1980'],
                 [ien.name, ien.title, ien.authors, ien.date_label]
    assert ien.text?
    refute RfcModel.rfc(-4).text?
    assert_equal 'rfc-editor.org/ien/ien4.pdf', RfcModel.rfc(-4).url
  end

  def test_iens_are_searched_but_not_on_the_rfc_shelves
    index
    assert_equal 'Issues in the Interconnection of Datagram Networks', RfcModel.rfc(-1).title
    assert_equal [-137], RfcModel.search(%w[holy wars]).map(&:number)
    refute_includes RfcModel.newest(20).map(&:number), -137
  end

  def test_errata
    index
    assert_equal({ total: 2, verified: 1 }, ErratumModel.counts(793))
    first = ErratumModel.of(793).first
    assert_equal [1001, 'Verified', 'Technical', '3.9'], [first.id, first.status, first.type, first.section]
    assert_includes first.correct_text, "\nbut special allowance"
    assert_equal({ total: 0, verified: 0 }, ErratumModel.counts(854))
  end

  def test_formats
    index
    assert RfcModel.rfc(793).text?
    refute RfcModel.rfc(854).text?
  end

  def test_of_month
    index
    assert_equal [1149, 2549], RfcModel.of_month(4, limit: 10).map(&:number)
    assert_equal 2, RfcModel.month_count(9)
  end

  def test_shelves_of_status_decade_and_newest
    index
    assert_equal ['INTERNET STANDARD', 3], RfcModel.statuses.first
    assert_equal [[1980, 2], [1990, 4], [2020, 1]], RfcModel.decades
    assert_equal [793, 854], RfcModel.of_decade(1980, limit: 10).map(&:number)
    assert_equal [9293, 2549], RfcModel.newest(2).map(&:number)
  end

  def test_a_failed_import_keeps_the_old_index
    index
    File.write(path('broken.xml'), '<rfc-index><rfc-entry><doc-id>RFC1</doc-id>')
    assert_raises(StandardError) { IndexBuilder.new.build(path('broken.xml')) }
    assert_equal 7, RfcModel.issued_count
    assert_equal 'Telnet Protocol Specification', RfcModel.rfc(854).title
    assert_equal({ total: 2, verified: 1 }, ErratumModel.counts(793))
  end

  def test_an_import_replaces_the_index
    index
    assert_equal 7, IndexBuilder.new.build(File.join(FIXTURES, 'rfc-index.xml'))
    assert_equal 0, ErratumModel.counts(793)[:total]
    assert_empty RfcModel.iens
    assert_equal [854], RfcModel.search(%w[telnet]).map(&:number)
  end

  def test_callers_read_the_old_index_while_the_new_one_is_built
    index
    reader = Rubbs::Common::Storage::Database.open(path('index.sqlite3'))
    during = RfcModel.rebuild { |_fts| reader[:rfcs].where(number: 854).get(:title) }
    assert_equal 'Telnet Protocol Specification', during
    refute RfcModel.ready?
  ensure
    close_database(reader) if reader
  end

  def test_an_index_of_an_older_board_is_emptied
    db = Sequel.sqlite(path('old-index.sqlite3'))
    db.run('CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, issued INTEGER)')
    db[:rfcs].insert(number: 1, title: 'Host Software', issued: 1)
    close_database(db)
    old = open_database('old-index.sqlite3', INDEX_MIGRATIONS, name: :index)
    refute RfcModel.ready?
    assert_equal 1, Rubbs::Common::Storage::Database.version(old)
    assert_equal 7, index
  ensure
    close_database(old) if old
  end
end
