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
    UI::Sysop.offer(@accounts)
    @auth = BBS.config.auth
    BBS.config.auth = BBS::Auth::Setup.new(directory: @accounts, login: :menu, guests: true)
    capture_io do
      @accounts.register('Tasi', 'secret1')
      @accounts.register('Spammer', 'secret1')
      @accounts.grant('tasi', 'sysop')
    end
  end

  def teardown
    BBS::Auth::Profile.clear_extras
    BBS.config.auth = @auth
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
    capture_io { assert_nil gate(%w[p s b q], roles: ['member']).run }
    refute_includes @line.output, 'SysOp'
    refute_includes @line.output, 'SYSOP ›'
  end

  def test_a_sysop_bans_an_account
    keys = ['p', 's', :tab, '/', *'spam'.chars, :enter, 'b', *'ads'.chars, :enter, 'y', 'q', 'b', 'q']
    capture_io { assert_nil gate(keys).run }
    entry = @accounts.entry('spammer')
    assert_equal [true, 'Tasi', 'ads'], [entry.banned?, entry.banned_by, entry.ban_reason]
    assert_includes @line.output, 'SYSOP › ACCOUNTS'
    capture_io { assert_equal :banned, @accounts.log_in('spammer', 'secret1', caller_key: 'line:1') }
  end

  def test_a_sysop_cannot_ban_themselves_or_drop_their_sysop_role
    g = gate(['p', 's', :tab, :down, 'b', 'r', *'sysop'.chars, :enter])
    capture_io { assert_raises(BBS::Hangup) { g.run } }
    assert_includes @line.output, 'You cannot ban yourself.'
    assert_includes shown, 'Your own sysop role stays.'
    assert_includes @accounts.entry('tasi').roles, 'sysop'
    refute @accounts.entry('tasi').banned?
  end

  def test_the_calls_and_a_hang_up
    own   = Call.new('test', 'Tasi', '10.0.0.1', 'telnet', :modern, Time.now - 60, nil)
    other = Call.new('x', nil, '203.0.113.7', 'bbs-web', :petscii, Time.now - 600, '› Feedia BBS')
    BBS.stub(:calls, [own, other]) do
      capture_io { assert_nil gate(['p', 's', 'h', :down, 'h', 'y', 'q', 'b', 'q']).run }
    end
    assert other.hung
    refute own.hung
    assert_includes @line.output, 'That is your own call.'
    assert_includes @line.output, '› Feedia BBS'
    assert_includes @line.output, 'a guest hung up.'
  end

  def test_the_tabs_go_round_to_the_profile
    capture_io { assert_nil gate([:tab, :tab, 'b', :left, 'b', 'q']).run }
    assert_includes @line.output, 'PROFILE'
    assert_includes @line.output, 'Logged in as Tasi'
    assert_includes @line.output, 'SysOp'
  end

  def test_the_log
    capture_io { BBS.log('auth', 'login', name: 'Tasi') }
    g = gate(['p', 's', :left])
    capture_io { assert_raises(BBS::Hangup) { g.run } }
    assert_includes shown, 'SYSOP › LOG'
    assert_includes shown, 'auth: login name=Tasi'
  end
end
