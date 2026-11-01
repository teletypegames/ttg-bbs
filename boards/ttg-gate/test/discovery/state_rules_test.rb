# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class StateRulesTest < Minitest::Test
    DAY = StateRules::DAY
    NOW = 100 * DAY

    # Probes a day apart ending at NOW, oldest first: +results+ in order.
    def probes(*results)
      results.each_with_index.map { |r, i| { 'at' => NOW - ((results.size - 1 - i) * DAY), 'result' => r } }
    end

    def state(list, last_success_at: nil, first_probe_at: nil)
      last_success_at ||= list.reverse.find { |p| %w[ok silent].include?(p['result']) }&.dig('at')
      first_probe_at  ||= list.first&.dig('at')
      StateRules.state(list, last_success_at: last_success_at, first_probe_at: first_probe_at, now: NOW)
    end

    def test_unknown_without_a_probe
      assert_equal 'unknown', state([]).state
    end

    def test_online_needs_the_last_and_80_percent_of_the_week
      s = state(probes('ok', 'silent', 'ok', 'timeout', 'ok', 'ok', 'ok'))
      assert_equal 'online', s.state
      assert_in_delta 6.0 / 7, s.success_rate_7d
      assert_equal 0, s.failures
    end

    def test_flaky_below_80_percent
      assert_equal 'flaky', state(probes('timeout', 'ok', 'refused', 'timeout', 'ok')).state
    end

    def test_one_miss_after_a_success_is_flaky
      s = state(probes('ok', 'ok', 'ok', 'timeout'))
      assert_equal 'flaky', s.state
      assert_equal 1, s.failures
    end

    def test_two_misses_in_a_row_are_down
      s = state(probes('ok', 'ok', 'timeout', 'dns_fail'))
      assert_equal 'down', s.state
      assert_equal 2, s.failures
    end

    def test_never_reached_is_down_for_30_days_then_dead
      assert_equal 'down', state(probes('timeout')).state
      list = [{ 'at' => NOW - (29 * DAY), 'result' => 'timeout' }, { 'at' => NOW, 'result' => 'timeout' }]
      assert_equal 'down', state(list).state
      list = [{ 'at' => NOW - (30 * DAY), 'result' => 'timeout' }, { 'at' => NOW, 'result' => 'refused' }]
      assert_equal 'dead', state(list).state
    end

    def test_dead_after_30_days_without_success
      list = [{ 'at' => NOW - (31 * DAY), 'result' => 'ok' }] + probes('timeout', 'timeout')
      assert_equal 'dead', state(list).state
    end

    def test_a_dead_board_that_answers_comes_back
      list = probes('timeout', 'timeout', 'ok')
      assert_equal 'flaky', state(list, first_probe_at: NOW - (90 * DAY)).state
    end

    def test_closed_is_a_failure
      assert_equal 'down', state(probes('ok', 'closed', 'closed')).state
    end

    def test_schedule
      rand = Struct.new(:value) { def rand(_) = value }
      online = BoardStateModel.new(state: 'online', success_rate_7d: 1.0, failures: 0)
      assert_equal NOW + DAY + 3600, StateRules.next_probe_at(online, now: NOW, rand: rand.new(3600))
      assert_equal NOW + DAY - 7200, StateRules.next_probe_at(online, now: NOW, rand: rand.new(-7200))
      jitters = Array.new(200) { StateRules.next_probe_at(online, now: NOW) - NOW - DAY }
      assert(jitters.all? { |j| j.between?(-7200, 7200) })
      assert_equal NOW,
StateRules.next_probe_at(BoardStateModel.new(state: 'unknown', success_rate_7d: nil, failures: 0), now: NOW)
      [[1, 3600], [2, 6 * 3600], [3, DAY], [9, DAY]].each do |failures, wait|
        down = BoardStateModel.new(state: 'down', success_rate_7d: 0.0, failures: failures)
        assert_equal NOW + wait, StateRules.next_probe_at(down, now: NOW)
      end
      dead = BoardStateModel.new(state: 'dead', success_rate_7d: 0.0, failures: 40)
      assert_equal NOW + (7 * DAY), StateRules.next_probe_at(dead, now: NOW)
    end

    def test_archive_after_a_dead_year_when_delisted
      dead = BoardStateModel.new(state: 'dead', success_rate_7d: 0.0, failures: 50)
      long = NOW - (396 * DAY)
      assert StateRules.archived?(dead, delisted: true, last_success_at: long, first_probe_at: long, now: NOW)
      refute StateRules.archived?(dead, delisted: false, last_success_at: long, first_probe_at: long, now: NOW)
      refute StateRules.archived?(dead, delisted: true, last_success_at: NOW - (300 * DAY), first_probe_at: long, now: NOW)
    end
  end
end
