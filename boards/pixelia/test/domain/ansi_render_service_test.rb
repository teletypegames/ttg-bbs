# frozen_string_literal: true

require 'test_helper'

class AnsiRenderServiceTest < Minitest::Test
  def render(bytes) = AnsiRenderService.new.render(bytes)

  def test_plain_text_wraps_at_the_width
    art = render('x' * 81)
    assert_equal 80, art.width
    assert_equal 2, art.height
    assert_equal ['x', 7, 0], art.cells(1, 0, 1).first
  end

  def test_sgr_colours_bold_and_reverse
    art = render("\e[1;31mA\e[0;44mB\e[7mC\e[0mD")
    assert_equal [['A', 9, 0], ['B', 7, 4], ['C', 4, 7], ['D', 7, 0]], art.cells(0, 0, 4)
  end

  def test_extended_and_bright_codes
    art = render("\e[38;5;12mA\e[92mB\e[48;5;3mC")
    assert_equal [['A', 12, 0], ['B', 10, 0], ['C', 10, 3]], art.cells(0, 0, 3)
  end

  def test_cursor_moves_and_erase
    art = render("abc\e[2DZ\e[2;5HQ\e[sR\e[uS\e[1;1H\e[K")
    assert_equal ' ', art.cells(0, 0, 1).first.first
    assert_equal %w[Q S], art.cells(1, 4, 2).map(&:first)
  end

  def test_controls_become_cp437_pictures_and_sub_ends_the_art
    art = render("\x01\e]0;evil\x07ok\x1Aignored")
    assert_equal '☺]0;evilok', art.cells(0, 0, 10).map(&:first).join
    assert_equal 1, art.height
  end

  def test_rows_are_cut_at_max_rows
    art = AnsiRenderService.new(max_rows: 3).render("a\n" * 10)
    assert_equal 3, art.height
    assert art.truncated?
  end
end
