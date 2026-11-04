# frozen_string_literal: true

require 'test_helper'

# EditorService and its LoginGuard: passwords, and the limits on guessing
# them that a new call does not reset.
class EditorServiceTest < Minitest::Test
  include TestHelper

  def editors(guard = LoginGuard.new(per_name: 3, per_caller: 2))
    service = EditorService.new(guard: guard, fail_delay: 0)
    service.add('tasi', 'secret-pass')
    service
  end

  def quietly(&) = capture_io(&)

  def test_the_right_password_logs_in_whatever_the_case_of_the_name
    assert_equal 'tasi', editors.login(' TASI ', 'secret-pass', caller: '1.2.3.4').name
  end

  def test_a_wrong_password_or_name_is_wrong
    service = editors
    quietly do
      assert_equal :wrong, service.login('tasi', 'nope', caller: '1.2.3.4')
      assert_equal :wrong, service.login('nobody', 'secret-pass', caller: '5.6.7.8')
    end
  end

  def test_a_caller_is_locked_after_too_many_failures_even_on_a_new_call
    service = editors
    quietly { 2.times { |i| service.login("guess#{i}", 'x', caller: '1.2.3.4') } }
    assert_equal :locked, service.login('tasi', 'secret-pass', caller: '1.2.3.4')
    assert_operator service.locked_for('tasi', '1.2.3.4'), :>, 0
    assert_equal 'tasi', service.login('tasi', 'secret-pass', caller: '5.6.7.8').name
  end

  def test_a_name_is_locked_after_too_many_failures_from_anywhere
    service = editors
    quietly { 3.times { |i| service.login('Tasi', 'x', caller: "10.0.0.#{i}") } }
    assert_equal :locked, service.login('tasi', 'secret-pass', caller: '9.9.9.9')
    assert_equal 0.0, service.locked_for('other', '9.9.9.9')
  end

  def test_a_lockout_outlasts_a_restart
    stored = -> { LoginGuard.new(store: BBS::Database.open(db_path, MIGRATIONS), per_name: 3, per_caller: 2) }
    quietly { 2.times { |i| editors(stored.call).login("guess#{i}", 'x', caller: '1.2.3.4') } }
    assert_equal :locked, editors(stored.call).login('tasi', 'secret-pass', caller: '1.2.3.4')
  end

  def test_the_derivations_wait_for_a_free_slot
    guard = LoginGuard.new(slots: 1, slot_wait: 0.05)
    hold  = Queue.new
    busy  = Thread.new { guard.derive { hold.pop } }
    Thread.pass until busy.status == 'sleep'
    assert_equal :busy, editors(guard).login('tasi', 'secret-pass', caller: '1.2.3.4')
    hold << :done
    busy.join
    assert_equal 'tasi', editors(guard).login('tasi', 'secret-pass', caller: '1.2.3.4').name
  end

  def test_changing_the_password_needs_the_current_one
    service = editors
    assert_equal :wrong, service.change_password('tasi', 'nope', 'new-secret-pass')
    assert_equal :short_password, service.change_password('tasi', 'secret-pass', 'short')
    assert_equal :ok, service.change_password('tasi', 'secret-pass', 'new-secret-pass')
    assert_equal 'tasi', service.login('tasi', 'new-secret-pass', caller: '1.2.3.4').name
  end

  def test_names_and_passwords_are_checked_when_added
    service = editors
    assert_equal :bad_name, service.add('a b', 'secret-pass')
    assert_equal :short_password, service.add('zsolt', 'short')
    assert_equal :taken, service.add('TASI', 'secret-pass')
  end
end
