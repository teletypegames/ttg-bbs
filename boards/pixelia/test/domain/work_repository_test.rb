# frozen_string_literal: true

require 'test_helper'

class WorkRepositoryTest < Minitest::Test
  include TmpDir

  def setup
    super
    @works = File.join(@dir, 'works')
    @repo  = WorkRepository.new(@works)
  end

  def write_work(id, title)
    FileUtils.mkdir_p(@works)
    work = WorkModel.new(id: id, title: title, handle: 'h', created_at: Time.now, canvas: painted_canvas)
    File.write(File.join(@works, "#{id}.json"), JSON.generate(work.to_h))
  end

  def test_lists_newest_first_and_finds
    write_work('20261101-010000-aaaa', 'old')
    write_work('20261102-010000-bbbb', 'new')
    assert_equal %w[new old], @repo.all.map(&:title)
    assert_equal 'old', @repo.find('20261101-010000-aaaa').title
  end

  def test_a_save_reads_no_other_file
    write_work('20261101-010000-aaaa', 'old')
    @repo.all
    File.write(File.join(@works, '20261101-010000-aaaa.json'), 'overwritten, not read again')
    work = @repo.add(title: 't', handle: 'h', canvas: painted_canvas)
    assert_equal [work.id, '20261101-010000-aaaa'], @repo.all.map(&:id)
    assert_equal 'old', @repo.all.last.title
  end

  def test_files_added_or_removed_by_another_process_show_up
    write_work('20261101-010000-aaaa', 'a')
    assert_equal 1, @repo.all.size
    write_work('20261103-010000-cccc', 'c')
    File.delete(File.join(@works, '20261101-010000-aaaa.json'))
    assert_equal %w[c], @repo.all.map(&:title)
  end

  def test_a_broken_file_is_skipped_and_warned_once
    write_work('20261101-010000-aaaa', 'good')
    File.write(File.join(@works, '20261102-010000-bbbb.json'), '{"half":')
    _, err = capture_io { assert_equal %w[good], @repo.all.map(&:title) }
    assert_match(/bbbb/, err)
    write_work('20261104-010000-dddd', 'later')
    _, err = capture_io { @repo.all }
    assert_empty err
  end

  def test_remove
    work = @repo.add(title: 't', handle: 'h', canvas: painted_canvas)
    assert @repo.remove(work.id)
    refute @repo.remove(work.id)
    refute @repo.remove('../canvas')
    assert_empty @repo.all
  end
end
