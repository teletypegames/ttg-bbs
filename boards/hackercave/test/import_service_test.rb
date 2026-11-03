# frozen_string_literal: true

require 'test_helper'

class ImportServiceTest < Minitest::Test
  include TempDir

  # An RFC Editor that hands out the fixtures; +errata+ false makes
  # errata.json fail.
  class FakeEditor
    attr_reader :downloads

    def initialize(errata: true)
      @downloads = 0
      @errata = errata
    end

    def download_index(path)
      @downloads += 1
      FileUtils.cp(File.join(FIXTURES, 'rfc-index.xml'), path)
    end

    def download_errata(path)
      raise BBS::HTTP::Error, 'GET errata.json: answered 503' unless @errata

      FileUtils.cp(File.join(FIXTURES, 'errata.json'), path)
    end

    def ien_index = File.read(File.join(FIXTURES, 'ien-index.txt'))
    def ien_listing = File.read(File.join(FIXTURES, 'ien-listing.html'))
  end

  def import(editor)
    @index = IndexRepository.new(path('index.sqlite3'))
    ImportService.new(index: @index, editor: editor, index_file: path('rfc-index.xml'),
                      errata_file: path('errata.json'), ttl: 86_400)
  end

  def test_refresh_imports_once_until_stale
    editor = FakeEditor.new
    service = import(editor)
    assert_equal :updated, service.refresh
    assert_equal :fresh, service.refresh
    assert_equal 1, editor.downloads
    refute File.exist?(path('rfc-index.xml'))
    refute File.exist?(path('errata.json'))
    assert_equal 2, @index.errata_count(793)[:total]
    assert_equal 4, @index.iens.size
  end

  def test_an_index_of_an_older_board_is_imported_anew
    db = SQLite3::Database.new(path('index.sqlite3'))
    db.execute('CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, issued INTEGER)')
    db.close
    service = import(FakeEditor.new)
    refute @index.ready?
    assert service.stale?
    assert_equal :updated, service.refresh
    assert @index.ready?
  end

  def test_the_rfcs_come_without_the_errata
    service = import(FakeEditor.new(errata: false))
    assert_equal :updated, service.refresh
    assert_equal 7, @index.count
    assert_equal 0, @index.errata_count(793)[:total]
  end
end
