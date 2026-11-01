# frozen_string_literal: true

require 'test_helper'

class SupervisorServiceTest < Minitest::Test
  def service(password = 'pw')
    @now = 0
    SupervisorService.new(password, clock: -> { @now }).tap { |s| s.define_singleton_method(:sleep) { |_| nil } }
  end

  def test_without_a_password_nothing_unlocks
    assert_equal :unconfigured, service('').unlock('')
  end

  def test_the_password_unlocks
    assert_equal :granted, service.unlock('pw')
  end

  def test_ten_wrong_tries_lock_everyone_for_the_window
    s = service
    capture_io { 10.times { assert_equal :wrong, s.unlock('nope') } }
    assert_equal :locked, s.unlock('pw')
    @now = SupervisorService::FAILURE_WINDOW + 1
    assert_equal :granted, s.unlock('pw')
  end
end
