# frozen_string_literal: true

require_relative '../test_helper'

class TeletypeBBSTest < Minitest::Test
  ENVIRONMENT = %w[TELETYPE_BBS_DB TELETYPE_BBS_SYSOPS].freeze

  def setup
    @dir = Dir.mktmpdir('teletype-bbs')
    BBS.config.env_prefix = 'TELETYPE_BBS_'
    ENV['TELETYPE_BBS_DB'] = File.join(@dir, 'teletype.sqlite3')
    ENV['TELETYPE_BBS_SYSOPS'] = 'Tasi'
    @bbs = TeletypeBBS.new
  end

  def teardown
    ENVIRONMENT.each { |name| ENV.delete(name) }
    FileUtils.rm_rf(@dir)
  end

  def test_only_a_logged_on_sysop_broadcasts
    @bbs.chat.subscribe('s')
    assert_equal :forbidden, @bbs.sysop_broadcast('Kali', 'hi', registered: true)
    assert_equal :forbidden, @bbs.sysop_broadcast('Tasi', 'hi', registered: false)
    assert_equal :empty, @bbs.sysop_broadcast('Tasi', ' ', registered: true)
    assert_equal :ok, @bbs.sysop_broadcast('tasi', 'hello', registered: true)
    assert_equal ['[SYSOP] tasi', 'hello'], @bbs.chat.drain('s').map { |l| [l.username, l.text] }.last
  end

  def board_with_history
    calls = LastCallersRepository.new(@bbs.store)
    [%w[Kali a], %w[kali b], %w[Zed c], %w[Anonymous d]].each { |name, id| calls.record(name, id, 30) }
    @bbs.accounts.register('Kali', 'password', 'password')
    @bbs.boards.post('general', 'Kali', 'hi', caller_key: 'a')
    @bbs.trivia.add('Zed', 500, 7)
  end

  def test_the_statistics_come_from_sql
    board_with_history
    fame = @bbs.hall_of_fame
    assert_equal [['kali', 2], ['Zed', 1]], fame[:callers]
    assert_equal [['Kali', 1]], fame[:posters]
    assert_equal [['Zed', 500]], fame[:trivia]
    name, stats, = @bbs.user_rows.first
    assert_equal ['Kali', 2, 60], [name, stats.calls, stats.seconds]
    assert_equal 1, @bbs.my_stats('kali', registered: true, session_id: 'x', caller_number: 5, sysop: false)[:posts]
  end

  def test_bulletins_are_read_by_the_domain
    assert_match(/BBS/, @bbs.bulletins.read('newcomers.md'))
    assert_nil @bbs.bulletins.read('../../bbs.rb')
  end
end
