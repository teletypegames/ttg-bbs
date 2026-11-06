# frozen_string_literal: true

require_relative '../test_helper'

class TeletypeBBSTest < Minitest::Test
  include AccountsCase

  ENVIRONMENT = %w[TELETYPE_BBS_DB].freeze

  def setup
    @dir = Dir.mktmpdir('teletype-bbs')
    Rubbs.config.env_prefix = 'TELETYPE_BBS_'
    ENV['TELETYPE_BBS_DB'] = File.join(@dir, 'teletype.sqlite3')
    @bbs = TeletypeBBS.new
  end

  def teardown
    ENVIRONMENT.each { |name| ENV.delete(name) }
    FileUtils.rm_rf(@dir)
    super
  end

  def test_the_sysop_role_makes_a_sysop
    assert @bbs.sysop?(account('Tasi', :sysop))
    refute @bbs.sysop?(account('Kali'))
    refute @bbs.sysop?(Rubbs::Common::Auth::Identity.guest('Tasi'))
  end

  def board_with_history
    @bbs.databases
    [%w[Kali a], %w[kali b], %w[Zed c], %w[Anonymous d]].each { |name, id| CallModel.record(name, id, 30) }
    accounts
    @bbs.members.register('Kali', 'password', 'password')
    @bbs.trivia.add('Zed', 500, 7)
    notes = [%w[Kali hi], %w[Zed yo], %w[Kali again]].map { |name, text| { 'name' => name, 'text' => text, 'guest' => false } }
    wall = WallService.new(source: ->(_) { notes + [{ 'name' => 'Guest', 'text' => 'x', 'guest' => true }] })
    @bbs.define_singleton_method(:wall) { wall }
  end

  def test_the_statistics_come_from_sql
    board_with_history
    fame = @bbs.hall_of_fame
    assert_equal [['kali', 2], ['Zed', 1]], fame[:callers]
    assert_equal [['Kali', 2], ['Zed', 1]], fame[:wall]
    assert_equal [['Zed', 500]], fame[:trivia]
    name, stats, = @bbs.user_rows.first
    assert_equal ['Kali', 2, 60], [name, stats.calls, stats.seconds]
    assert_equal 5, @bbs.my_stats('kali', registered: true, session_id: 'x', caller_number: 5)[:caller_number]
  end

  def test_bulletins_are_read_by_the_domain
    assert_match(/BBS/, @bbs.bulletins.read('newcomers.md'))
    assert_nil @bbs.bulletins.read('../../bbs.rb')
  end
end
