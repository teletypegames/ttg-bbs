# frozen_string_literal: true

require 'test_helper'

class TextCacheRepositoryTest < Minitest::Test
  include TempDir

  def cache(max_bytes = 1 << 20) = TextCacheRepository.new(path('texts'), max_bytes: max_bytes)

  def test_stores_a_text_and_reads_a_chapter_without_control_characters
    texts = cache
    model = texts.store(1, "One\f\n\nTwo \e[2Jlines", [['One', 0, 4], ['Two', 6, 13]])

    assert_equal model, texts.index(1)
    assert_equal 'One', texts.read(1, model.chapter(1))
    assert_equal 'Two [2Jlines', texts.read(1, model.chapter(2))
  end

  def test_forgets_the_books_read_least_recently
    texts = cache(300)
    texts.store(1, 'a' * 150, [['A', 0, 150]])
    File.utime(Time.now - 60, Time.now - 60, path('texts/1.json'))
    texts.store(2, 'b' * 150, [['B', 0, 150]])

    assert_nil texts.index(1)
    refute_nil texts.index(2)
  end
end
