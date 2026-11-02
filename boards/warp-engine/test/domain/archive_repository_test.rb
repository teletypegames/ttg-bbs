# frozen_string_literal: true

require 'test_helper'

class ArchiveRepositoryTest < Minitest::Test
  include BoardTest

  def setup
    super
    @archive = ArchiveRepository.new('http://archive.example/', ttl: 300)
    @calls = []
  end

  def answer(*bodies)
    lambda do |url, **options|
      @calls << [url, options]
      body = bodies.shift
      body.is_a?(Exception) ? raise(body) : response(body)
    end
  end

  def test_reads_an_index_once_and_cleans_it
    index = "#SHELF 1\n#{BoardTest.line(title: "Ga\e]52;c;evil\ame")}"
    titles = BBS::HTTP.stub(:get, answer(index)) { 2.times.map { @archive.titles(SHELF) } }.last

    assert_equal ['Ga]52;c;evilme'], titles.map(&:title)
    assert_equal 1, @calls.size
    assert_equal 'http://archive.example/C64/INDEX.TXT', @calls[0][0]
  end

  def test_fresh_reads_again_and_keeps_the_last_index_when_the_archive_fails
    failure = BBS::HTTP::Error.new('GET http://archive.example/C64/INDEX.TXT: the deadline passed')
    titles = quietly do
      BBS::HTTP.stub(:get, answer(BoardTest.line, failure)) do
        @archive.titles(SHELF)
        @archive.titles(SHELF, fresh: true)
      end
    end

    assert_equal ['Game'], titles.map(&:title)
    assert_equal 2, @calls.size
  end

  def test_fresh_replaces_the_kept_index
    newer = BoardTest.line(title: 'Newer')
    titles = BBS::HTTP.stub(:get, answer(BoardTest.line, newer)) do
      @archive.titles(SHELF)
      @archive.titles(SHELF, fresh: true)
      @archive.titles(SHELF)
    end

    assert_equal ['Newer'], titles.map(&:title)
    assert_equal 2, @calls.size
  end

  def test_raises_when_the_archive_never_answered
    BBS::HTTP.stub(:get, ->(*, **) { response('gone', status: 404) }) do
      assert_raises(BBS::HTTP::Error) { @archive.titles(SHELF) }
      assert_raises(BBS::HTTP::Error) { @archive.titles(SHELF, fresh: true) }
    end
  end

  def test_file_is_capped
    data = BBS::HTTP.stub(:get, answer('GAME')) { @archive.file('/C64/GAME.PRG', max_bytes: 100) }

    assert_equal 'GAME', data
    assert_equal 100, @calls[0][1][:max_bytes]
  end

  private

  def quietly(&block)
    result = nil
    capture_io { result = block.call }
    result
  end
end
