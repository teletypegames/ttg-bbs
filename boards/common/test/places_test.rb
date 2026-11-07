# frozen_string_literal: true

require_relative 'test_helper'

# The places of the profile: every letter takes one place, and none is the
# profile's own (Log in, New account, Change password, Log out, Back).
class PlacesTest < Minitest::Test
  OWN = %w[l n c b].freeze

  def setup = TTG::Badges.network

  def test_every_place_has_a_letter_of_its_own
    letters = Rubbs::Common::Auth::Profile.extras.map(&:hotkey)
    assert_equal letters.uniq, letters
    assert_empty letters & OWN
    assert_equal 'a', Rubbs::Common::Auth::Profile.extras.find { |e| e.key == :badges }.hotkey
  end
end
