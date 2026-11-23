# frozen_string_literal: true

require 'test_helper'

class PetsciiModelTest < Minitest::Test
  def picture(name = 'ttg-logo') = PetsciiModel.from_tcv(TcvModel.parse(tcv_fixture(name)))

  def blank(background: 0)
    PetsciiModel.new(charset: :upper, border: 0, background: background, screen: [0x20] * 1000, colors: [1] * 1000)
  end

  def test_from_a_tcv
    assert_equal :upper, picture.charset
    assert_equal :lower, picture('charmap').charset
    refute picture.empty?
  end

  def test_json_round_trip
    original = picture('charmap')
    again = PetsciiModel.from_h(JSON.parse(JSON.generate(original.to_h)))
    assert_equal [original.screen, original.colors, original.border, original.charset],
                 [again.screen, again.colors, again.border, again.charset]
  end

  def test_broken_json_is_no_picture
    hash = picture.to_h
    assert_nil PetsciiModel.from_h(hash.merge('charset' => 'custom'))
    assert_nil PetsciiModel.from_h(hash.merge('screen' => hash['screen'][1..]))
    assert_nil PetsciiModel.from_h(hash.merge('color' => ['zz' * 20] * 25))
    assert_nil PetsciiModel.from_h(hash.merge('border' => '1'))
  end

  def test_empty_is_what_shows_only_the_background
    assert blank.empty?
    assert blank(background: 1).empty?
    assert blank(background: 6).empty?, 'spaces on a blue screen are a blue screen'
    reversed = PetsciiModel.new(charset: :upper, border: 0, background: 0, screen: [0xa0] + ([0x20] * 999), colors: [2] * 1000)
    refute reversed.empty?
  end

  def test_screen_codes_print_as_their_petscii
    assert_equal(
      [0x40, 0x41, 0x20, 0x31, 0xc0, 0xdf, 0xa0, 0xbf, 0x41],
      [0x00, 0x01, 0x20, 0x31, 0x40, 0x5f, 0x60, 0x7f, 0x81].map { |c| PetsciiModel.petscii(c) }
    )
  end

  def test_every_screen_code_has_one_printable_look_alike
    %i[upper lower].each do |charset|
      (0..0x7f).each do |code|
        look = PetsciiGlyphModel.look(code, charset)
        assert_equal 1, look.length, "#{charset} #{code.to_s(16)}"
        assert(look != '?' || code == 0x3f, "#{charset} #{code.to_s(16)} has no look-alike")
      end
    end
    assert_equal(%w[A ─ ♠], [0x01, 0x40, 0x41].map { |c| PetsciiGlyphModel.look(c, :upper) })
    assert_equal(%w[a ─ A ✔], [0x01, 0x40, 0x41, 0x7a].map { |c| PetsciiGlyphModel.look(c, :lower) })
  end
end
