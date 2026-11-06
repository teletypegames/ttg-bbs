# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/ui/petscii'

# The sysop's console on a C64: the profile's SysOp, the accounts (a ban),
# the calls (a hang-up) and the log, on 40 columns.
class PetsciiSysopTest < Minitest::Test
  Canvas = Rubbs::Petscii::Canvas
  Call = Struct.new(:session_id, :caller_name, :caller_ip, :call_via, :face, :started_at, :place, :hung) do
    def hang_up = self.hung = true
  end

  def setup
    @accounts = Rubbs::Test.accounts(roles: ['member'])
    capture_io do
      @accounts.register('Tasi', 'secret1')
      @accounts.register('Spammer', 'secret1')
      @accounts.grant('tasi', 'sysop')
    end
    UI::Sysop.offer(@accounts)
    @auth = Rubbs.config.auth
    Rubbs.config.auth = Rubbs::Common::Auth::Setup.new(directory: @accounts, login: :menu, guests: true)
  end

  def teardown
    Rubbs::Common::Auth::Profile.clear_extras
    Rubbs.config.auth = @auth
  end

  def line(keys, roles: ['sysop'])
    identity = Rubbs::Common::Auth::Identity.new(id: 1, name: 'Tasi', roles: roles, source: :login)
    @line = Rubbs::Test::Session.new(keys: keys, identity: identity, petscii: true, cols: 40, rows: 25)
  end

  def console(keys) = UI::Petscii::Sysop.run(line(keys), @accounts)

  def shown = Canvas.new.feed(@line.take).to_s

  def test_sysop_is_in_the_profile_of_a_sysop_only
    ran = []
    UI::Petscii::Sysop.stub(:run, ->(session, _accounts) { ran << session.identity.roles }) do
      capture_io { Rubbs::Common::Auth::Profile.run(line(%w[s b])) }
      capture_io { Rubbs::Common::Auth::Profile.run(line(%w[s b], roles: ['member'])) }
    end
    assert_equal [%w[sysop]], ran
  end

  def test_a_ban_on_a_c64
    keys = ['a', '/', *'spam'.chars, :enter, 'b', *'ads'.chars, :enter, 'y']
    capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console(keys) } }
    entry = @accounts.entry('spammer')
    assert_equal [true, 'Tasi', 'ads'], [entry.banned?, entry.banned_by, entry.ban_reason]
    screen = shown
    assert_includes screen, 'BANNED'
    assert_includes screen, '*Spammer'
  end

  def test_no_ban_of_oneself_on_a_c64
    capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console(['a', :down, 'b']) } }
    assert_includes shown, 'You cannot ban yourself.'
    refute @accounts.entry('tasi').banned?
  end

  def test_the_calls_and_a_hang_up_on_a_c64
    own   = Call.new('test', 'Tasi', '10.0.0.1', 'telnet', :petscii, Time.now - 60, nil)
    other = Call.new('x', nil, '203.0.113.7', 'bbs-web', :modern, Time.now - 600, '› Feedia BBS')
    Rubbs.stub(:calls, [own, other]) do
      capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console([:down]) } }
      screen = shown
      assert_includes screen, 'Tasi (you)'
      assert_includes screen, 'Feedia BBS'
      capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console([:down, :enter, 'y']) } }
    end
    refute own.hung
    assert other.hung
  end

  def test_the_log_on_a_c64
    capture_io { Rubbs.log('auth', 'login', name: 'Tasi') }
    capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console(['l']) } }
    screen = shown
    assert_includes screen, 'LOG'
    assert_includes screen, 'auth: login name=Tasi'
  end

  def test_a_member_gets_no_console
    capture_io { assert_raises(Rubbs::Common::Line::Hangup) { console_for(['a'], roles: ['member']) } }
    assert_includes shown, 'The console is for a sysop.'
  end

  private

  def console_for(keys, roles:) = UI::Petscii::Sysop.run(line(keys, roles: roles), @accounts)
end
