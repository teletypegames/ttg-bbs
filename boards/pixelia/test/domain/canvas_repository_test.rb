# frozen_string_literal: true

require 'test_helper'

class CanvasRepositoryTest < Minitest::Test
  include TmpDir

  def repo(flush_seconds: 2)
    CanvasRepository.new(path('canvas.json'), archive_dir: path('archive'), clear_flag: path('canvas.clear'),
                                              flush_seconds: flush_seconds)
  end

  def path(name) = File.join(@dir, name)

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

  # Runs the block with the writer started on +r+, every 20 ms.
  def writing(r)
    r.start
    thread = Thread.list.find { |t| t.name == 'bbs: canvas writer' }
    yield
  ensure
    thread&.kill
  end

  def test_the_writer_writes_in_the_background
    r = repo(flush_seconds: 0.02)
    r.put(0, 'A', 2, 0)
    writing(r) { sleep 0.01 until File.exist?(path('canvas.json')) }
    assert_equal ['A', 2, 0], repo.snapshot.at(0, 0)
  end

  def test_the_writer_answers_the_clear_flag
    r = repo(flush_seconds: 0.02)
    r.put(0, 'A', 2, 0)
    File.write(path('canvas.clear'), '')
    writing(r) { sleep 0.01 while File.exist?(path('canvas.clear')) }
    assert r.snapshot.empty?
    assert_equal 1, Dir.children(path('archive')).size
  end

  def test_a_broken_canvas_starts_blank
    File.write(File.join(@dir, 'canvas.json'), '{"broken')
    _, err = capture_io { assert repo.snapshot.empty? }
    assert_match(/canvas.json/, err)
  end
end
