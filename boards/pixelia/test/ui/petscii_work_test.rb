# frozen_string_literal: true

require 'test_helper'
require 'rubbs/test'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# A PETSCII work on both faces: the C64's own screen codes, the modern
# face's look-alikes.
class PetsciiWorkTest < Minitest::Test
  W = UI::Petscii::WorkScreen
  C = Rubbs::Petscii::Canvas

  def test_the_charmap_goes_out_in_the_lower_set
    charmap = PetsciiModel.from_tcv(TcvModel.parse(tcv_fixture('charmap')))
    assert_equal [C::LOWERCASE, C::CLEAR], W.bytes(charmap).bytes.first(2)
  end

  def test_on_black_every_cell_is_as_painted
    assert_equal [0x41, false, 2], W.cell(0x01, 2, 0)
    assert_equal [0x41, true, 2], W.cell(0x81, 2, 0)
  end

  def test_on_another_background_the_nearest_a_black_screen_shows
    blue = 6
    assert_equal [0x20, true, blue], W.cell(0x20, 1, blue), 'a space is the background'
    assert_equal [0x20, true, blue], W.cell(0x01, blue, blue), 'ink in the background colour is the background'
    assert_equal [0x41, true, blue], W.cell(0x01, 0, blue), 'black ink: exact, reversed in the background'
    assert_equal [0x20, true, 2], W.cell(0xa0, 2, blue), 'a reversed space is its ink'
    assert_equal [0x41, true, 2], W.cell(0x81, 2, blue), 'a reversed character keeps its ink'
    assert_equal [0x41, true, blue], W.cell(0x01, 2, blue), 'ink on a background keeps the background'
  end

  def test_the_modern_face_swaps_the_colours_of_a_reversed_cell
    screen = [0x01, 0x81] + ([0x20] * 998)
    work = PetsciiModel.new(charset: :lower, border: 14, background: 6, screen: screen, colors: [1] * 1000)
    assert_equal ['a', 1, 6], UI::Modern::ArtLines.petscii_cell(work, 0, 0)
    assert_equal ['a', 6, 1], UI::Modern::ArtLines.petscii_cell(work, 1, 0)
    framed = UI::Modern::ArtLines.petscii_framed(work, 0, 0, 44)
    assert_includes framed, "48;5;#{ColorModel[14].xterm}m"
    assert_includes UI::Modern::ArtLines.petscii_framed(work, 1, 0, 44), 'a'
  end
end
