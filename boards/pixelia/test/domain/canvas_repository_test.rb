# frozen_string_literal: true

require 'test_helper'

class CanvasRepositoryTest < Minitest::Test
  include TmpDir

  def repo
    CanvasRepository.new(File.join(@dir, 'canvas.json'), archive_dir: File.join(@dir, 'archive'),
                                                         clear_flag: File.join(@dir, 'canvas.clear'))
  end

  def test_put_flush_and_load
    r = repo
    assert_equal [' ', 0, 0], r.put(0, 'A', 2, 0)
    assert_nil r.put(0, 'B', 2, 0, expect: [' ', 0, 0])
    r.flush
    assert_equal ['A', 2, 0], repo.snapshot.at(0, 0)
  end

  def test_clear_archives_whole_files_each_time
    r = repo
    r.put(0, 'A', 2, 0)
    first  = r.clear
    second = r.clear
    refute_equal first, second
    assert_equal ['A', 2, 0], CanvasModel.from_h(JSON.parse(File.read(first))).at(0, 0)
    assert_empty Dir.glob(File.join(@dir, '**', '*.tmp'))
    assert r.snapshot.empty?
  end

  def test_a_broken_canvas_starts_blank
    File.write(File.join(@dir, 'canvas.json'), '{"broken')
    _, err = capture_io { assert repo.snapshot.empty? }
    assert_match(/canvas.json/, err)
  end
end
