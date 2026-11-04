# frozen_string_literal: true

require 'test_helper'

class LegacyReadsTest < Minitest::Test
  include TempDir

  LINES = <<~JSONL
    {"at":"2026-11-01T00:19:50Z","book":1342}
    {"at":"2026-11-01T00:21:10Z","book":345}
    {"at":"2026-11-01T00:22:03Z","book":345}
    {"at":"2026-11-01T00:23:0
    {"at":"yesterday","book":11}
    {"book":"84"}

    {"at":"2026-11-01T01:00:00Z","book":"84"}
  JSONL

  def setup
    super
    @file = path('reads.jsonl')
    File.write(@file, LINES)
  end

  def test_imports_the_good_lines_and_renames_the_file
    result = nil
    _, err = capture_io { result = LegacyReads.import(@file) }

    assert_equal [4, 3], result
    assert_equal [[345, 2], [84, 1], [1342, 1]], ReadModel.top(10)
    refute_path_exists @file
    assert_path_exists "#{@file}.imported"
    assert_match 'imported 4 reads from reads.jsonl (3 skipped)', err
  end

  def test_keeps_the_time_of_a_read
    capture_io { LegacyReads.import(@file) }

    assert_equal '2026-11-01T00:19:50Z', ReadModel.where(book_id: 1342).get(:at)
  end

  def test_leaves_the_file_when_the_table_has_reads
    ReadModel.add(1)

    assert_nil LegacyReads.import(@file)
    assert_path_exists @file
    assert_equal 1, ReadModel.top(10).size
  end

  def test_does_nothing_without_a_file
    assert_nil LegacyReads.import(path('none.jsonl'))
  end
end
