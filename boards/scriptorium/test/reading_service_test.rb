# frozen_string_literal: true

require 'test_helper'

class ReadingServiceTest < Minitest::Test
  include TempDir

  TEXT = "CHAPTER I\n\n#{'Call me Ishmael. ' * 30}\n\nCHAPTER II\n\n#{'Some years ago. ' * 30}".freeze

  # A mirror that counts the texts asked for, gives +answer+, and can be
  # made to wait.
  class FakeGutenberg
    attr_reader :asked

    def initialize(answer)
      @answer = answer
      @asked  = Queue.new
      @gate   = Queue.new
      @wait   = false
    end

    def hold! = @wait = true
    def release!(n = 1) = n.times { @gate << :go }

    def text(id, max_bytes:)
      @asked << [id, max_bytes]
      @gate.pop if @wait
      raise @answer if @answer.is_a?(Exception)

      +@answer
    end
  end

  def service(answer = TEXT)
    @gutenberg = FakeGutenberg.new(answer)
    ReadingService.new(gutenberg: @gutenberg, cache: TextCacheRepository.new(path('texts'), max_bytes: 1 << 20),
                       chapters: ChapterService.new, max_bytes: 1000)
  end

  def book(id = 2701) = BookModel.stub(id: id, title: 'Moby Dick')

  def test_opens_a_book_once_and_reads_its_chapters_from_the_cache
    reading = service
    text = reading.open(book)

    assert_equal 2, text.size
    assert_equal 'CHAPTER II', reading.chapter(text, 2).lines.first.strip
    assert_equal text, reading.open(book)
    assert_equal 1, @gutenberg.asked.size
    assert reading.cached?(book)
  end

  def test_counts_a_read_once_a_call
    reading = service
    seen = Set.new
    2.times { reading.open(book, seen: seen) }
    reading.open(book, seen: Set.new)
    reading.open(book)

    assert_equal 2, ReadModel.count_of(2701)
  end

  def test_tells_why_a_book_does_not_open
    assert_equal :too_big, service(BBS::HTTP::TooLarge.new('GET https://m/x: the body is over 1000 bytes')).open(book)
    _, err = capture_io { assert_equal :unavailable, service(BBS::HTTP::Error.new('GET https://m/x: answered 404')).open(book) }
    assert_match(%r{: gutenberg: book 2701: GET https://m/x: answered 404}, err)
    assert_equal :empty, service('').open(book)
    assert_equal 0, ReadModel.count_of(2701)
  end

  def test_callers_of_one_book_share_one_fetch
    reading = service
    @gutenberg.hold!
    callers = Array.new(4) { Thread.new { reading.open(book) } }
    @gutenberg.asked.pop
    sleep 0.05
    @gutenberg.release!(4)

    assert_equal [2], callers.map(&:value).map(&:size).uniq
    assert_equal 0, @gutenberg.asked.size
  end

  def test_fetches_at_most_a_few_books_at_once
    reading = service
    @gutenberg.hold!
    callers = (1..(ReadingService::FETCHES + 1)).map { |id| Thread.new { reading.open(book(id)) } }
    ReadingService::FETCHES.times { @gutenberg.asked.pop }
    sleep 0.05

    assert_equal 0, @gutenberg.asked.size
    @gutenberg.release!(ReadingService::FETCHES + 1)
    callers.each(&:join)

    assert_equal 1, @gutenberg.asked.size
  end
end
