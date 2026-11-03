# frozen_string_literal: true

require 'test_helper'

class LibraryServiceTest < Minitest::Test
  include TempDir

  # An RFC Editor that hands out the fixture index.
  class FakeEditor
    attr_reader :downloads

    def initialize = @downloads = 0

    def download_index(path)
      @downloads += 1
      FileUtils.cp(File.join(FIXTURES, 'rfc-index.xml'), path)
    end
  end

  def library(index_repo: IndexRepository.new(path('index.sqlite3')), editor: FakeEditor.new)
    LibraryService.new(index: index_repo, shelves: ShelvesRepository.new(File.expand_path('../config/shelves.yml', __dir__)),
                       reads: ReadRepository.new(database), editor: editor, index_file: path('rfc-index.xml'),
                       ttl: 86_400)
  end

  def test_before_the_index_only_the_own_shelves_stand
    lib = library
    assert_equal ['Classics', 'Telnet', 'April 1st'], lib.shelves.map(&:name)
    assert_equal :preparing, lib.search('telnet')
    telnet = lib.entries_on(lib.own_shelves[1]).first
    assert_equal [854, 'Telnet Protocol Specification', 'the line you are on now'],
                 [telnet.number, telnet.rfc.title, telnet.note]
  end

  def test_refresh_imports_once_until_stale
    editor = FakeEditor.new
    lib = library(editor: editor)
    assert_equal :updated, lib.refresh
    assert_equal :fresh, lib.refresh
    assert_equal 1, editor.downloads
    refute File.exist?(path('rfc-index.xml'))
    assert_includes lib.shelves.map(&:name), 'STD'
  end

  def test_search_by_number
    lib = library(index_repo: index)
    assert_equal [854], lib.search('854').map(&:number)
    assert_equal [854], lib.search('RFC 854').map(&:number)
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

  def test_links_and_relations
    lib = library(index_repo: index)
    rfc = lib.rfc(793)
    assert_equal({ 'obsoleted by' => [9293] }, lib.relations(rfc))
    assert_equal([['obsoleted by', 9293]], lib.links(rfc).map { |e| [e.note, e.number] })
  end

  def test_most_read_counts_reads
    lib = library(index_repo: index)
    reads = ReadRepository.new(database)
    2.times { reads.add(854) }
    reads.add(793)
    assert_equal([[854, 2], [793, 1]], lib.most_read.map { |e| [e.number, e.note] })
  end
end
