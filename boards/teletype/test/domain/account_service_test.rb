# frozen_string_literal: true

require_relative '../test_helper'

class AccountServiceTest < Minitest::Test
  include DatabaseCase

  def setup
    super
    @pauses   = []
    @accounts = AccountService.new(reserved: ['Tasi'],
                                   guard: LoginGuard.new(per_name: 4, per_caller: 3),
                                   pause: ->(seconds) { @pauses << seconds })
  end

  def register(name) = @accounts.register(name, 'password', 'password')

  def test_register_and_log_on
    assert_equal :ok, register('Kali')
    assert_equal :ok, @accounts.log_on('KALI', caller_key: 'a') { 'password' }
    assert_equal :guest, @accounts.log_on('Nobody', caller_key: 'a') { flunk }
  end

  def test_register_refuses_taken_reserved_and_look_alike_names
    register('Kali')
    assert_equal :taken, register('kali')
    assert_equal :look_alike, register('Kаli')
    assert_equal :look_alike, register('KAL1')
    assert_equal :reserved, register('TASl')
    assert_equal :anonymous, register('anonymous')
    assert_equal :too_short, @accounts.register('Zed', 'abc', 'abc')
    assert_equal :mismatch, @accounts.register('Zed', 'password', 'passworD')
  end

  def test_create_is_atomic_against_a_race
    assert_equal :ok, AccountModel.register('Zed', 'aa' * 16, 'bb' * 32)
    assert_equal :taken, AccountModel.register('ZED', 'cc' * 16, 'dd' * 32)
    assert_equal 'bb' * 32, AccountModel.named('zed').digest
  end

  def test_a_look_alike_guest_is_turned_away
    register('Kali')
    assert_equal :look_alike, @accounts.log_on('Kаli', caller_key: 'a') { flunk }
  end

  def test_three_wrong_passwords_with_growing_pauses
    register('Kali')
    agains = []
    result = @accounts.log_on('Kali', caller_key: 'a') { |again| agains << again; 'wrong' }
    assert_equal :wrong, result
    assert_equal [false, true, true], agains
    assert_equal [2, 4, 6], @pauses
  end

  def test_the_line_is_locked_after_its_limit
    register('Kali')
    @accounts.log_on('Kali', caller_key: 'a') { 'wrong' }
    assert_equal :locked, @accounts.log_on('Kali', caller_key: 'a') { 'password' }
    assert_equal :ok, @accounts.log_on('Kali', caller_key: 'b') { 'password' }
  end

  def test_the_name_is_locked_from_any_line
    register('Kali')
    @accounts.log_on('Kali', caller_key: 'a') { 'wrong' }
    @accounts.log_on('Kali', caller_key: 'b') { 'wrong' }
    assert_equal :locked, @accounts.log_on('Kali', caller_key: 'c') { 'password' }
  end

  def test_a_dropped_line
    register('Kali')
    assert_equal :dropped, @accounts.log_on('Kali', caller_key: 'a') { nil }
  end

  def test_set_password_creates_and_resets
    assert_equal :ok, @accounts.set_password('Tasi', 'sysop-pass')
    created = @accounts.created_at('tasi')
    assert_equal :ok, @accounts.set_password('tasi', 'new-pass')
    assert_equal :ok, @accounts.log_on('Tasi', caller_key: 'a') { 'new-pass' }
    assert_equal created, @accounts.created_at('Tasi')
  end

  def test_skeletons
    assert_equal Names.skeleton('Tasi'), Names.skeleton('TаSI')
    assert_equal Names.skeleton('Ola'), Names.skeleton('Οla')
    refute_equal Names.skeleton('Tasi'), Names.skeleton('Tasa')
  end
end
