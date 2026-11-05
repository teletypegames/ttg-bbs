# frozen_string_literal: true

require 'test_helper'

class LogoTest < Minitest::Test
  def test_both_drawings_load_at_their_size
    assert_equal [66, 23], [TTG::Logo.art(:modern).cols, TTG::Logo.art(:modern).rows]
    assert_equal [33, 23], [TTG::Logo.art(:petscii).cols, TTG::Logo.art(:petscii).rows]
    assert TTG::Logo.art(:petscii).petscii?
  end

  def test_the_splash_shows_the_logo
    splash = TTG::Logo.splash
    assert_instance_of Rubbs::Common::Call::Splash, splash
    assert_same TTG::Logo.art(:modern), splash.modern
    assert_equal Rubbs::Common::Call::Splash::PROMPT, splash.prompt
  end

  def test_the_c64_drawing_fits_the_screen
    assert Rubbs::Petscii::Art.bytes(TTG::Logo.art(:petscii)).bytesize.positive?
  end
end
