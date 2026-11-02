# frozen_string_literal: true

require_relative '../test_helper'

# What a restart must not undo (the limits kept in the database), and
# what the composition root hands the characters.
class PersistenceTest < Minitest::Test
  include DatabaseCase

  def accounts
    service = AccountService.new(AccountRepository.new(@db), guard: LoginGuard.new(store: @db, per_name: 3),
                                                             pause: ->(_) {})
    service.register('Kali', 'password', 'password')
    service
  end

  def test_a_login_lockout_outlasts_a_restart
    assert_equal :wrong, accounts.log_on('Kali', caller_key: 'a') { 'nope' }
    assert_equal :locked, accounts.log_on('Kali', caller_key: 'b') { 'password' }
  end

  def test_a_post_cooldown_outlasts_a_restart
    boards = -> { BoardService.new(BoardRepository.new(@db), last_read: LastReadRepository.new(@db), store: @db) }
    assert_equal :ok, boards.call.post('general', 'Kali', 'hi', caller_key: 'a')
    assert_equal :too_fast, boards.call.post('general', 'Kali', 'again', caller_key: 'b')
  end

  def test_the_characters_model_falls_back_to_sermos
    env = { 'SERMO_LLM_URL' => 'http://llm:8080', 'TELETYPE_BBS_LLM_URL' => '' }
    assert_equal 'http://llm:8080', TeletypeBBS.llm(env).url
    assert_equal 'http://own:1', TeletypeBBS.llm(env.merge('TELETYPE_BBS_LLM_URL' => 'http://own:1')).url
  end

  def test_a_failing_site_is_logged_and_shows_nothing
    site = SiteService.new(Object.new.tap { |repo| def repo.members = raise(BBS::HTTP::Error, 'down') })
    _, err = capture_io { assert_empty site.members }
    assert_match(/site members: BBS::HTTP::Error: down/, err)
  end
end
