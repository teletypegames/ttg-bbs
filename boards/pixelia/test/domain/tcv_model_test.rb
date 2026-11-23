# frozen_string_literal: true

require 'test_helper'

class TcvModelTest < Minitest::Test
  def logo = tcv_fixture('ttg-logo')

  def test_reads_the_samples
    logo_tcv = TcvModel.parse(logo)
    assert logo_tcv.hires?
    assert_equal [TcvModel::ROM_UPPER, 0, 0], [logo_tcv.charset, logo_tcv.border, logo_tcv.background]
    assert_equal 1000, logo_tcv.screen.size
    charmap = TcvModel.parse(tcv_fixture('charmap'))
    assert_equal [TcvModel::ROM_LOWER, 11], [charmap.charset, charmap.border]
  end

  def test_reads_game_graphics_too
    tiles = TcvModel.parse(tcv_fixture('game-tiles'))
    refute tiles.hires?
    assert tiles.custom_charset?
    assert_equal 2048, tiles.chars.bytesize
  end

  def test_a_load_address_in_front_is_skipped
    assert_equal TcvModel.parse(logo).screen, TcvModel.parse("\x00\xC0".b + logo).screen
  end

  def test_xmodem_padding_after_the_picture_is_ignored
    assert_equal TcvModel.parse(logo).colors, TcvModel.parse(logo + ("\x1A" * 80)).colors
  end

  def test_colours_are_masked_to_their_low_nibble
    data = logo.dup
    data.setbyte(TcvModel::HEADER + TcvModel::CELLS, 0xf3)
    assert_equal 3, TcvModel.parse(data).colors.first
  end

  def refusal(data)
    TcvModel.parse(data)
    flunk 'parsed'
  rescue TcvModel::FormatError => e
    e.message
  end

  def with_byte(offset, value) = logo.dup.tap { |d| d.setbyte(offset, value) }

  def test_broken_files_are_refused_with_a_reason
    assert_equal 'not a TTG Canvas 64 picture', refusal('GIF89a'.b + logo)
    assert_equal 'the header is cut short', refusal('TC64'.b)
    assert_equal 'version 2 is not known', refusal(with_byte(4, 2))
    assert_equal 'mode 2 is not known', refusal(with_byte(5, 2))
    assert_equal 'character set 3 is not known', refusal(with_byte(6, 3))
    assert_equal 'a colour is out of range', refusal(with_byte(8, 16))
  end

  def test_a_short_file_is_refused_with_its_length
    assert_equal 'the picture is cut short (2000 of 2016 bytes)', refusal(logo[0, 2000])
    assert_match(/cut short \(2016 of 4064/, refusal(with_byte(6, 2)))
  end
end
