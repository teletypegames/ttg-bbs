# frozen_string_literal: true

require 'test_helper'

class CatalogServiceTest < Minitest::Test
  include BoardTest

  # An archive that holds one file.
  FakeArchive = Struct.new(:data) do
    def file(_path, max_bytes:) = data && data[0, max_bytes + 1]
  end

  def catalog(data, max_bytes: 100)
    @downloads = DownloadRepository.new(database)
    CatalogService.new(shelves: nil, archive: FakeArchive.new(data), downloads: @downloads, max_bytes: max_bytes)
  end

  def title = TitleModel.parse(BoardTest.line, SHELF)

  def test_gives_the_bytes_the_index_promises
    assert_equal 'GAME', catalog('GAME').fetch(title)
  end

  def test_refuses_what_does_not_match
    assert_equal :too_big, catalog('GAME', max_bytes: 3).fetch(title)
    assert_equal :unavailable, catalog(nil).fetch(title)
    assert_equal :changed, catalog('GAMF').fetch(title)
    assert_equal :changed, catalog('GAMES').fetch(title)
  end

  def test_counts_a_download
    service = catalog('GAME')
    service.downloaded(title, :zmodem)

    assert_equal 1, service.downloads(title)
  end
end
