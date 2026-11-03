# frozen_string_literal: true

require 'test_helper'

class PresetTest < Minitest::Test
  def test_the_preset_brings_the_logo_and_the_address
    assert_same TTG::Logo.splash, TTG::PRESET.splash
    assert_equal 'teletypegames.org', TTG::PRESET.url
    assert_equal 21, BBS::QR.modules(TTG::PRESET.qr).size
  end
end
