# frozen_string_literal: true

require 'test_helper'

class WallServiceTest < Minitest::Test
  include TmpDir

  Canvas = Struct.new(:snapshot)

  def wall(canvas: painted_canvas, cooldown: 300, per_hour: 30)
    WallService.new(WorkRepository.new(File.join(@dir, 'works')), canvas: Canvas.new(canvas),
                                                                  cooldown: cooldown, per_hour: per_hour)
  end

  def test_saves_a_work_with_clean_title_and_handle
    work = wall.save('1.2.3.4', title: "  Sun\e[2J‮set \t  ", handle: "ada​\x07")
    assert_kind_of WorkModel, work
    assert_equal 'Sun[2Jset', work.title
    assert_equal 'ada', work.handle
  end

  def test_title_and_handle_are_cut_to_their_limit
    work = wall.save('k', title: 'x' * 50, handle: 'y' * 50)
    assert_equal WallService::MAX_TITLE, work.title.length
    assert_equal WallService::MAX_HANDLE, work.handle.length
  end

  def test_refusals
    w = wall
    assert_equal :no_title, w.save('k', title: " \x01 ", handle: 'a')
    assert_equal :no_handle, w.save('k', title: 'a', handle: '')
    assert_equal :blank_canvas, wall(canvas: CanvasModel.blank).save('k', title: 'a', handle: 'b')
  end

  def test_a_caller_waits_the_cooldown_whatever_its_session
    w = wall
    assert_kind_of WorkModel, w.save('1.2.3.4', title: 'a', handle: 'b')
    assert_equal :too_soon, w.save('1.2.3.4', title: 'c', handle: 'd')
    assert_operator w.wait('1.2.3.4'), :>, 290
    assert_equal 0, w.wait('5.6.7.8')
    assert_kind_of WorkModel, w.save('5.6.7.8', title: 'c', handle: 'd')
  end

  def test_the_board_saves_at_most_per_hour_works
    w = wall(per_hour: 2)
    2.times { |i| assert_kind_of WorkModel, w.save("caller-#{i}", title: 'a', handle: 'b') }
    assert_equal :too_soon, w.save('caller-9', title: 'a', handle: 'b')
    assert_operator w.wait('caller-9'), :>, 3500
    assert_equal 2, w.all.size
  end

  def test_a_failed_write_costs_no_turn
    w = wall
    File.write(File.join(@dir, 'works'), 'a file where the folder should be')
    capture_io { assert_equal :failed, w.save('k', title: 'a', handle: 'b') }
    assert_equal 0, w.wait('k')
  end
end
