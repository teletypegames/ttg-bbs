# frozen_string_literal: true

require 'test_helper'

class LibraryServiceTest < Minitest::Test
  include TempDir

  # A mirror whose index has the words "avian" in RFC 1149.
  class FakeMirror
    def ready? = true

    def search(words, limit:)
      words.first == 'avian' ? [[1149, 'IP datagrams on avian carriers'], [99, 'gone']].first(limit) : []
    end
  end

  def library(index_repo: IndexRepository.new(path('index.sqlite3')), mirror: nil)
    LibraryService.new(index: index_repo, shelves: ShelvesRepository.new(File.expand_path('../config/shelves.yml', __dir__)),
                       reads: ReadRepository.new(database), mirror: mirror, clock: -> { Time.new(2026, 4, 1) })
  end

  def test_before_the_index_only_the_own_shelves_stand
    lib = library
    assert_equal ['Classics', 'Telnet', 'April 1st'], lib.shelves.map(&:name)
    assert_equal :preparing, lib.search('telnet')
    telnet = lib.entries_on(lib.own_shelves[1]).first
    assert_equal [854, 'Telnet Protocol Specification', 'the line you are on now'],
                 [telnet.number, telnet.rfc.title, telnet.note]
  end

  def test_the_shelves_of_the_index
    lib = library(index_repo: index)
    names = lib.shelves.map(&:name)
    assert_includes names, 'STD'
    assert_includes names, 'This month: April'
    assert_equal 'IENs', names.last
    month = lib.shelves.find { |s| s.kind == :month }
    assert_equal([[1149, '1990'], [2549, '1999']], lib.entries_on(month).map { |e| [e.number, e.note] })
    assert_equal [-1, -4, -7, -137], lib.entries_on(lib.shelves.last).map(&:number)
  end

  def test_search_by_number
    lib = library(index_repo: index)
    assert_equal [854], lib.search('854').map(&:number)
    assert_equal [854], lib.search('RFC 854').map(&:number)
    assert_equal [-137], lib.search('ien 137').map(&:number)
    assert_equal [:not_issued, 14], lib.search('rfc14')
    assert_equal [:unknown, 12_345], lib.search('12345')
  end

  def test_search_by_series_and_words
    lib = library(index_repo: index)
    assert_equal([[9293, 'STD 7']], lib.search('std 7').map { |e| [e.number, e.note] })
    assert_equal [2549], lib.search('avian year:1999').map(&:number)
    assert_equal [793, 854, 9293].sort, lib.search('status:standard').map(&:number).sort
    assert_equal :too_short, lib.search('a')
  end

  def test_search_the_text
    assert_equal :preparing, library(index_repo: index).search_text('avian')
    lib = library(index_repo: index, mirror: FakeMirror.new)
    assert lib.text_search?
    assert_equal([[1149, 'IP datagrams on avian carriers', :match]], lib.search_text('avian').map { |e|
      [e.number, e.note, e.kind]
    })
    assert_equal :too_short, lib.search_text('a')
  end

  def test_links_relations_errata_and_mentions
    lib = library(index_repo: index)
    rfc = lib.rfc(793)
    assert_equal({ 'obsoleted by' => [9293] }, lib.relations(rfc))
    assert_equal([['obsoleted by', 9293]], lib.links(rfc).map { |e| [e.note, e.number] })
    assert_equal({ total: 2, verified: 1 }, lib.errata_count(rfc))
    assert_equal([[854, 3], [-137, 10]], lib.mentioned([[854, 2], [99_999, 4], [-137, 9]]).map { |e| [e.number, e.note] })
  end

  def test_most_read_counts_reads
    lib = library(index_repo: index)
    reads = ReadRepository.new(database)
    2.times { reads.add(854) }
    reads.add(793)
    assert_equal([[854, 2], [793, 1]], lib.most_read.map { |e| [e.number, e.note] })
  end
end
