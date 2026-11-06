# frozen_string_literal: true

require_relative 'test_helper'

# The board's own words for ttg-common's screens: a key ttg-common does not know would stop the
# board at boot.
class ContentTest < Minitest::Test
  CONTENT = File.expand_path('../lib/content', __dir__)

  def test_the_mailbox_words
    narrative = TTG::PrivateMessage.narrative_of(File.join(CONTENT, 'mail.yml'))
    assert_equal 'Your mailbox', narrative.text(:title)
    assert_match(/ANYONE WITH AN ACCOUNT/, narrative.text(:intro, petscii: true))
  end

  def test_the_wall_words
    assert_equal 'The post office wall', TTG::Wall.narrative_of(File.join(CONTENT, 'wall.yml')).text(:title)
  end
end
