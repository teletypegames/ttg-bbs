# frozen_string_literal: true

require 'test_helper'

class PresetTest < Minitest::Test
  def test_the_preset_brings_the_logo_and_the_address
    assert_same TTG::Logo.splash, TTG::PRESET.splash
    assert_equal 'teletypegames.org', TTG::PRESET.url
    assert_equal 21, Rubbs::Common::Text::QR.modules(TTG::PRESET.qr).size
  end

  def test_the_profile_has_the_small_mark
    look = TTG::PRESET.profile
    assert_equal([[44, 13], [22, 13]], [look.modern, look.petscii].map { |art| [art.cols, art.rows] })
    assert look.petscii.petscii?
    assert_equal 'PROFILE', look.title
  end
end
