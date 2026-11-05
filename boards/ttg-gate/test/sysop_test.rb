# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'discovery/face_fixtures'

# The sysop's console on the modern face: only for the sysop role; the
# accounts (a ban), the calls (a hang-up) and the log.
class SysopTest < Minitest::Test
  Bbs = Struct.new(:directory, :browse, :dials, :accounts)
  Directory = Struct.new(:boards)
  Call = Struct.new(:session_id, :caller_name, :caller_ip, :call_via, :face, :started_at, :place, :hung) do
    def hang_up = self.hung = true
  end

  def setup
    @accounts = BBS::Test.accounts(roles: ['member'])
    capture_io do
      @accounts.register('Tasi', 'secret1')
      @accounts.register('Spammer', 'secret1')
      @accounts.grant('tasi', 'sysop')
    end
  end

  def gate(keys, roles: ['sysop'])
    identity = BBS::Auth::Identity.new(id: 1, name: 'Tasi', roles: roles, source: :login)
    @line = BBS::Test::Session.new(keys: keys, identity: identity, cols: 100, rows: 30)
    UI::Modern::Gate.new(@line, Bbs.new(Directory.new(boards), nil, nil, @accounts))
  end

  def boards
    BoardRepository.new(File.expand_path('../config/boards.yml', __dir__), host: 'localhost', public_host: 'example.org').all
  end

  def shown = Discovery::FaceFixtures::Terminal.new(100, 30).feed(@line.output).to_s

  def test_a_member_has_no_console
    g = gate(%w[s q], roles: ['member'])
    assert_nil g.run
    refute_includes @line.output, 'SYSOP'
    refute_includes @line.output, 'S sysop'
  end

  def test_a_sysop_bans_an_account
    keys = ['s', '2', '/', *'spam'.chars, :enter, :enter, 'b', *'ads'.chars, :enter, 'y', 'q', 'q', 'q', 'q']
    capture_io { assert_nil gate(keys).run }
    entry = @accounts.entry('spammer')
    assert_equal [true, 'Tasi', 'ads'], [entry.banned?, entry.banned_by, entry.ban_reason]
    assert_includes @line.output, 'SYSOP › ACCOUNTS › Spammer'
    capture_io { assert_equal :banned, @accounts.log_in('spammer', 'secret1', caller_key: 'line:1') }
  end

  def test_a_sysop_cannot_ban_themselves_or_drop_their_sysop_role
    g = gate(['s', '2', :down, :enter, 'b'])
    assert_raises(BBS::Hangup) { g.run }
    assert_includes shown, 'You cannot ban yourself.'
    @line.keys.push('r', *'sysop'.chars, :enter)
    assert_raises(BBS::Hangup) { g.run }
    assert_includes shown, 'Your own sysop role stays.'
    assert_includes @accounts.entry('tasi').roles, 'sysop'
    refute @accounts.entry('tasi').banned?
  end

  def test_the_calls_and_a_hang_up
    own   = Call.new('test', 'Tasi', '10.0.0.1', 'telnet', :modern, Time.now - 60, nil)
    other = Call.new('x', nil, '203.0.113.7', 'bbs-web', :petscii, Time.now - 600, '› Feedia BBS')
    BBS.stub(:calls, [own, other]) do
      capture_io { assert_nil gate(['s', '1', 'h', :down, 'h', 'y', 'q', 'q', 'q']).run }
    end
    assert other.hung
    refute own.hung
    assert_includes @line.output, 'That is your own call.'
    assert_includes @line.output, '› Feedia BBS'
    assert_includes @line.output, 'a guest hung up.'
  end

  def test_the_log
    capture_io { BBS.log('auth', 'login', name: 'Tasi') }
    g = gate(%w[s 3])
    capture_io { assert_raises(BBS::Hangup) { g.run } }
    assert_includes shown, 'SYSOP › LOG'
    assert_includes shown, 'auth: login name=Tasi'
  end
end
