# frozen_string_literal: true

require_relative '../test_helper'

# What the composition root hands the characters, and how a failing remote
# source shows.
class PersistenceTest < Minitest::Test
  include DatabaseCase

  def test_the_characters_model_falls_back_to_sermos
    env = { 'SERMO_LLM_URL' => 'http://llm:8080', 'TELETYPE_BBS_LLM_URL' => '' }
    assert_equal 'http://llm:8080', TeletypeBBS.llm(env).url
    assert_equal 'http://own:1', TeletypeBBS.llm(env.merge('TELETYPE_BBS_LLM_URL' => 'http://own:1')).url
  end

  def test_a_failing_site_is_logged_and_shows_nothing
    site = SiteService.new(Object.new.tap { |repo| def repo.members = raise(Rubbs::Common::Web::HTTP::Error, 'down') })
    _, err = capture_io { assert_empty site.members }
    assert_match(/site members: Rubbs::Common::Web::HTTP::Error: down/, err)
  end
end
