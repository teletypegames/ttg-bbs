# frozen_string_literal: true

require_relative '../test_helper'

# The logon on the accounts of the network: a guest, an account and its
# password, a look-alike, and the members the board remembers.
class MemberServiceTest < Minitest::Test
  include DatabaseCase
  include AccountsCase

  def setup
    super
    accounts
    @members = MemberService.new(directory: -> { BBS.config.auth&.directory }, pause: ->(_) {})
  end

  def test_a_name_without_an_account_comes_in_as_a_guest
    identity = @members.log_on('Nobody', caller_key: 'a') { flunk }
    assert identity.guest?
    assert_equal 'Nobody', identity.name
    assert_equal 'Anonymous', MemberService.normalize_name("  \e[2J ")
    assert_equal 'Anonymous', @members.log_on('Anonymous', caller_key: 'a') { flunk }.name
  end

  def test_an_account_with_the_right_password
    account('Kali')
    identity = @members.log_on('KALI', caller_key: 'a') { 'password' }
    assert identity.signed_in?
    assert_equal 'Kali', identity.name
  end

  def test_three_wrong_passwords
    account('Kali')
    agains = []
    result = @members.log_on('Kali', caller_key: 'a') do |again|
      agains << again
      'wrong'
    end
    assert_equal :wrong, result
    assert_equal [false, true, true], agains
    assert_equal :dropped, @members.log_on('Kali', caller_key: 'a') { nil }
  end

  def test_a_look_alike_of_an_account_is_refused
    account('Kali')
    assert_equal :look_alike, @members.log_on('Kаli', caller_key: 'a') { flunk }
  end

  def test_a_registered_name_is_a_member
    assert_equal :anonymous, @members.register('Anonymous', 'password', 'password')
    assert_equal :mismatch, @members.register('Zed', 'password', 'passworD')
    identity = @members.register('Zed', 'password', 'password')
    assert identity.signed_in?
    assert_equal :taken, @members.register('zed', 'password', 'password')
    assert_equal ['Zed'], @members.names
    assert_equal 'Zed', @members.canonical('ZED')
    account('Ada')
    assert_equal 'ada', @members.canonical('ada')
    assert_nil @members.canonical('Nobody')
  end
end
