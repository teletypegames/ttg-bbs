# frozen_string_literal: true

require 'test_helper'

class ExhibitionServiceTest < Minitest::Test
  include TmpDir

  Canvas = Struct.new(:snapshot)

  def exhibition(canvas: painted_canvas, cooldown: 300, per_hour: 30, notify: nil)
    ExhibitionService.new(
      WorkRepository.new(File.join(@dir, 'works')),
      canvas:   Canvas.new(canvas),
      cooldown: cooldown,
      per_hour: per_hour,
      notify:   notify
    )
  end

  def logo = exhibition.accept(tcv_fixture('ttg-logo'))

  def test_saves_a_work_with_clean_title_and_handle
    work = exhibition.save('1.2.3.4', title: "  Sun\e[2J‮set \t  ", handle: "ada​\x07")
    assert_kind_of WorkModel, work
    assert_equal 'Sun[2Jset', work.title
    assert_equal 'ada', work.handle
  end

  def test_title_and_handle_are_cut_to_their_limit
    work = exhibition.save('k', title: 'x' * 50, handle: 'y' * 50)
    assert_equal ExhibitionService::MAX_TITLE, work.title.length
    assert_equal ExhibitionService::MAX_HANDLE, work.handle.length
  end

  def test_refusals
    w = exhibition
    assert_equal :no_title, w.save('k', title: " \x01 ", handle: 'a')
    assert_equal :no_handle, w.save('k', title: 'a', handle: '')
    assert_equal :blank_canvas, exhibition(canvas: CanvasModel.blank).save('k', title: 'a', handle: 'b')
  end

  def test_a_caller_waits_the_cooldown_whatever_its_session
    w = exhibition
    assert_kind_of WorkModel, w.save('1.2.3.4', title: 'a', handle: 'b')
    assert_equal :too_soon, w.save('1.2.3.4', title: 'c', handle: 'd')
    assert_operator w.wait('1.2.3.4'), :>, 290
    assert_equal 0, w.wait('5.6.7.8')
    assert_kind_of WorkModel, w.save('5.6.7.8', title: 'c', handle: 'd')
  end

  def test_the_board_saves_at_most_per_hour_works
    w = exhibition(per_hour: 2)
    2.times { |i| assert_kind_of WorkModel, w.save("caller-#{i}", title: 'a', handle: 'b') }
    assert_equal :too_soon, w.save('caller-9', title: 'a', handle: 'b')
    assert_operator w.wait('caller-9'), :>, 3500
    assert_equal 2, w.all.size
  end

  def test_a_save_the_board_refuses_costs_the_caller_nothing
    w = exhibition(per_hour: 1)
    w.save('a', title: 'a', handle: 'b')
    w.save('k', title: 'a', handle: 'b')
    assert w.instance_variable_get(:@callers).room?('k')
  end

  def test_a_failed_write_costs_no_turn
    w = exhibition
    File.write(File.join(@dir, 'works'), 'a file where the folder should be')
    capture_io { assert_equal :failed, w.save('k', title: 'a', handle: 'b') }
    assert_equal 0, w.wait('k')
  end

  def test_accepts_hires_pictures_in_either_rom_set
    assert_kind_of PetsciiModel, logo
    assert_equal :lower, exhibition.accept(tcv_fixture('charmap')).charset
    assert_kind_of PetsciiModel, exhibition.accept("\x01\x08".b + tcv_fixture('ttg-logo') + ("\x1A" * 94))
  end

  def test_refuses_game_graphics
    assert_equal :game_graphics, exhibition.accept(tcv_fixture('game-tiles')).reason
    multicolour = tcv_fixture('ttg-logo').tap { |d| d.setbyte(5, 1) }
    assert_equal :game_graphics, exhibition.accept(multicolour).reason
  end

  def test_refuses_broken_large_and_blank_files
    broken = exhibition.accept('hello'.b)
    assert_equal [:broken, 'not a TTG Canvas 64 picture'], [broken.reason, broken.detail]
    assert_equal :broken, exhibition.accept(tcv_fixture('ttg-logo') * 3).reason

    blank = tcv_fixture('ttg-logo').tap { |d| 1000.times { |i| d.setbyte(16 + i, 0x20) } }
    assert_equal :blank, exhibition.accept(blank).reason
  end

  def test_an_upload_hangs_a_petscii_work_and_notes_it
    notes = []
    w = exhibition(notify: ->(work, actor) { notes << [work.id, actor] })
    work = w.hang('k', title: ' Logo ', handle: 'ada', picture: logo, actor: :ada)
    assert_kind_of WorkModel, work
    assert work.petscii?
    assert_equal 'Logo', work.title
    assert_equal [[work.id, :ada]], notes
    assert_equal logo.screen, w.find(work.id).petscii.screen
  end

  def test_uploads_and_saves_share_the_limits
    notes = []
    w = exhibition(notify: ->(work, _) { notes << work })
    assert_kind_of WorkModel, w.save('k', title: 'a', handle: 'b')
    assert_equal :too_soon, w.hang('k', title: 'a', handle: 'b', picture: logo)
    assert_equal :no_title, w.hang('j', title: '', handle: 'b', picture: logo)
    assert_empty notes
    assert_kind_of WorkModel, w.hang('j', title: 'a', handle: 'b', picture: logo)
    assert_equal :too_soon, w.save('j', title: 'a', handle: 'b')
  end
end
