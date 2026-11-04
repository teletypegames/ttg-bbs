# frozen_string_literal: true

require_relative 'test_helper'
require 'bbs/test'
require_relative '../../lib/ui/account'

# The caller's account on the gate: a new account, the password, log out
# and in again, on a line of keys.
class AccountTest < Minitest::Test
  def setup = @accounts = BBS::Test.accounts(roles: ['member'])

  # A key alone is pressed as it is; a word in brackets is typed and RETURN pressed.
  def keys(*presses) = presses.flat_map { |press| press.is_a?(Array) ? [*press.first.chars, :enter] : [press] }

  def run_with(*presses, identity: nil)
    session = BBS::Test::Session.new(keys: keys(*presses), identity: identity)
    UI::Account.run(session, @accounts)
    session
  end

  def test_a_new_account_logs_the_caller_in
    session = run_with('n', ['Ada'], ['secret1'], ['secret1'], 'x', :enter)
    assert_equal ['Ada', %w[member]], [session.identity.name, session.identity.roles]
    assert_includes session.output, 'Your account is ready'
  end

  def test_log_in_change_the_password_and_log_out
    @accounts.register('Ada', 'secret1')
    session = run_with('l', ['ada'], ['secret1'], 'x', 'p', ['secret1'], ['secret2'], ['secret2'], 'x', 'o', :enter)
    assert session.identity.guest?
    assert_equal 'Ada', @accounts.log_in('ada', 'secret2', caller_key: 'line:1').name
  end

  def test_what_goes_wrong_is_said
    @accounts.register('Ada', 'secret1')
    session = run_with('n', ['ada'], ['secret1'], ['secret1'], 'x', :enter)
    assert_includes session.output, 'That name has an account'
    assert session.identity.guest?
  end
end
