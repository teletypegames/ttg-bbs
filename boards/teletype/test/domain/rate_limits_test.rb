# frozen_string_literal: true

require_relative '../test_helper'

class RateLimitsTest < Minitest::Test
  include DatabaseCase

  def accounts
    AccountService.new(AccountRepository.new(@db), pause: ->(_) {}).tap do |a|
      a.register('Kali', 'password', 'password')
    end
  end

  def test_a_post_every_cooldown_by_name_and_by_line
    boards = BoardService.new(BoardRepository.new(@db), last_read: LastReadRepository.new(@db))
    assert_equal :ok, boards.post('general', 'Kali', 'hi', caller_key: 'a')
    assert_equal :too_fast, boards.post('general', 'Kali', 'again', caller_key: 'b')
    assert_equal :too_fast, boards.post('general', 'Zed', 'me too', caller_key: 'a')
    assert_equal :ok, boards.post('general', 'Zed', 'me too', caller_key: 'b2')
    assert_equal :unknown, boards.post('nowhere', 'Ada', 'x', caller_key: 'c')
    assert_equal :empty, boards.post('general', 'Ada', " \e ", caller_key: 'c')
  end

  def test_anonymous_callers_are_counted_by_line_only
    boards = BoardService.new(BoardRepository.new(@db), last_read: LastReadRepository.new(@db))
    assert_equal :ok, boards.post('general', 'Anonymous', 'one', caller_key: 'a')
    assert_equal :ok, boards.post('general', 'Anonymous', 'two', caller_key: 'b')
  end

  def test_posts_are_cleaned_and_capped
    repo   = BoardRepository.new(@db)
    boards = BoardService.new(repo, last_read: LastReadRepository.new(@db))
    boards.post('general', 'Kali', "hi\e[2J‮#{'x' * 2000}", caller_key: 'a')
    text = repo.last('general').last.text
    assert text.start_with?('hi[2Jx')
    assert_equal BoardService::MAX_LENGTH, text.length
  end

  def test_chat_bursts_and_line_length
    chat = ChatService.new
    chat.subscribe('s')
    statuses = (1..(ChatService::BURST + 1)).map { |i| chat.say('Kali', "line #{i}", caller_key: 'a') }
    assert_equal ([:ok] * ChatService::BURST) + [:too_fast], statuses
    assert_equal :ok, chat.say('Zed', 'x' * 500, caller_key: 'b')
    assert_equal ChatService::MAX_LENGTH, chat.drain('s').last.text.length
    assert_equal :empty, chat.say('Zed', "\e\a", caller_key: 'c')
  end

  def test_guest_feedback_has_a_daily_cap
    mail = MailService.new(MailRepository.new(@db), accounts: accounts, sysops: [])
    stub_cooldown(mail)
    results = (1..(MailService::GUEST_DAILY + 1)).map do |i|
      mail.send_letter('Guest', 'Sysop', "s#{i}", 'body', registered: false, caller_key: 'a')
    end
    assert_equal ([:ok] * MailService::GUEST_DAILY) + [:daily_limit], results
    assert_equal :guest, mail.send_letter('Guest', 'Kali', 's', 'b', registered: false, caller_key: 'z')
    assert_equal :ok, mail.send_letter('Kali', 'Sysop', 's', 'b', registered: true, caller_key: 'q')
  end

  def test_mail_cooldown
    mail = MailService.new(MailRepository.new(@db), accounts: accounts, sysops: [])
    assert_equal :ok, mail.send_letter('Kali', 'kali', 'hi', 'body', registered: true, caller_key: 'a')
    assert_equal :too_fast, mail.send_letter('Kali', 'kali', 'hi', 'body', registered: true, caller_key: 'b')
    letter = mail.inbox('Kali').first
    assert_equal ['Kali', 'hi', false], [letter.to, letter.subject, letter.read?]
  end

  def test_oneliner_cooldown
    wall = OnelinerService.new(OnelinerRepository.new(@db))
    assert_equal :ok, wall.add('Kali', 'hello', caller_key: 'a')
    assert_equal :too_fast, wall.add('Kali', 'again', caller_key: 'b')
    assert_equal :too_long, wall.add('Zed', 'x' * 65, caller_key: 'c')
  end

  private

  # The guest cap, not the cooldown, is under test.
  def stub_cooldown(mail)
    mail.instance_variable_set(:@throttle, Throttle.new(limit: 100, per: 1))
  end
end
