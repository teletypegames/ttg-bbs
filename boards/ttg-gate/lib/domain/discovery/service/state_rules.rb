# frozen_string_literal: true

module Discovery
  # The state of a board from its probes, and when to call it next: the fixed
  # rules of TTG_DISCOVERY.md §5.2-5.3. ok and silent are successes.
  module StateRules
    DAY  = 86_400
    HOUR = 3600
    # The share of successes in 7 days an online board needs.
    ONLINE_RATE = 0.8
    # Without a success this long a board is dead.
    DEAD_AFTER = 30 * DAY
    # Delisted and dead this long: archived, no more probes.
    ARCHIVE_AFTER = 365 * DAY
    # The wait after the 1st, 2nd and later failures in a row.
    BACKOFF = [HOUR, 6 * HOUR, 24 * HOUR].freeze
    ONLINE_EVERY = 24 * HOUR
    JITTER       = 2 * HOUR
    DEAD_EVERY   = 7 * DAY

    # What the probes of a board add up to, kept in its board_state row.
    #
    # [state]           online, flaky, down, dead or unknown
    #                   (BoardStateModel::STATES)
    # [success_rate_7d] the share of successful probes in the last 7 days, nil
    #                   without a probe there
    # [failures]        the failed probes since the last success
    Verdict = Data.define(:state, :success_rate_7d, :failures)

    module_function

    # The Verdict of a board at +now+.
    #
    # [probes]          its probes of the last 30 days at least, oldest first
    #                   (Hashes with :at and :result)
    # [last_success_at] its last successful probe ever, or nil
    # [first_probe_at]  its first probe ever, or nil
    #
    # - unknown: no probe yet.
    # - online: the last probe succeeded, and >= 80% of the last 7 days did.
    # - flaky: the last probe succeeded, but < 80% of the last 7 days did; or
    #   one failure right after a success (one miss is not down yet).
    # - dead: no success for 30 days; a board never reached is dead 30 days
    #   after its first probe.
    # - down: otherwise (two or more failures in a row, or never reached yet).
    def state(probes, last_success_at:, first_probe_at:, now:)
      return Verdict.new(state: 'unknown', success_rate_7d: nil, failures: 0) if probes.empty? && first_probe_at.nil?

      week = probes.select { |p| p[:at] >= now - (7 * DAY) }
      rate = week.empty? ? nil : week.count { |p| success?(p) }.fdiv(week.size)
      failures = probes.reverse.take_while { |p| !success?(p) }.size
      Verdict.new(
        state:           name(probes, failures, rate, last_success_at, first_probe_at, now),
        success_rate_7d: rate,
        failures:        failures
      )
    end

    def name(probes, failures, rate, last_success_at, first_probe_at, now)
      if failures.zero? && probes.any?
        rate.to_f >= ONLINE_RATE ? 'online' : 'flaky'
      elsif now - (last_success_at || first_probe_at) >= DEAD_AFTER
        'dead'
      elsif failures == 1 && last_success_at
        'flaky'
      else
        'down'
      end
    end

    # The next probe time of a board in +state+ (a Verdict), seconds;
    # +rand+ gives the spread of an online board (a Random, or anything with
    # #rand(Range)).
    def next_probe_at(state, now:, rand: Random)
      case state.state
      when 'unknown' then now
      when 'dead' then now + DEAD_EVERY
      when 'down', 'flaky'
        return now + BACKOFF[[state.failures, BACKOFF.size].min - 1] if state.failures.positive?

        now + ONLINE_EVERY + rand.rand(-JITTER..JITTER)
      else now + ONLINE_EVERY + rand.rand(-JITTER..JITTER)
      end
    end

    # Whether a board is archived: delisted, and dead for a year (no success
    # for 30 days + a year).
    def archived?(state, delisted:, last_success_at:, first_probe_at:, now:)
      return false unless delisted && state.state == 'dead'

      now - (last_success_at || first_probe_at || now) >= DEAD_AFTER + ARCHIVE_AFTER
    end

    def success?(probe) = ProbeResultModel::SUCCESSES.include?(probe[:result])
  end
end
