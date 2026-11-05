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
      raise Rubbs::Common::Web::HTTP::Error, 'GET errata.json: answered 503' unless @errata

      FileUtils.cp(File.join(FIXTURES, 'errata.json'), path)
    end

    def ien_index = File.read(File.join(FIXTURES, 'ien-index.txt'))
    def ien_listing = File.read(File.join(FIXTURES, 'ien-listing.html'))
  end

  def import(editor)
    ImportService.new(editor: editor, index_file: path('rfc-index.xml'), errata_file: path('errata.json'), ttl: 86_400)
  end

  def test_refresh_imports_once_until_stale
    editor = FakeEditor.new
    service = import(editor)
    assert_equal :updated, service.refresh
    assert_equal :fresh, service.refresh
    assert_equal 1, editor.downloads
    refute File.exist?(path('rfc-index.xml'))
    refute File.exist?(path('errata.json'))
    assert_equal 2, ErratumModel.counts(793)[:total]
    assert_equal 4, RfcModel.iens.size
  end

  def test_an_index_of_an_older_board_is_imported_anew
    db = Sequel.sqlite(path('old-index.sqlite3'))
    db.run('CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, issued INTEGER)')
    db[:rfcs].insert(number: 1, title: 'Host Software', issued: 1)
    close_database(db)
    old = open_database('old-index.sqlite3', INDEX_MIGRATIONS, name: :index)
    service = import(FakeEditor.new)
    refute RfcModel.ready?
    assert service.stale?
    assert_equal :updated, service.refresh
    assert RfcModel.ready?
  ensure
    close_database(old) if old
  end

  def test_the_rfcs_come_without_the_errata
    service = import(FakeEditor.new(errata: false))
    assert_equal :updated, service.refresh
    assert_equal 7, RfcModel.issued_count
    assert_equal 0, ErratumModel.counts(793)[:total]
  end
end
