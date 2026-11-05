# frozen_string_literal: true

require_relative '../test_helper'

# The members the board remembers on the accounts of the network.
class MemberServiceTest < Minitest::Test
  include DatabaseCase
  include AccountsCase

  def setup
    super
    accounts
    @members = MemberService.new(directory: -> { Rubbs.config.auth&.directory })
  end

  def test_a_blank_or_malformed_name_is_anonymous
    assert_equal 'Anonymous', MemberService.normalize_name("  \e[2J ")
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
