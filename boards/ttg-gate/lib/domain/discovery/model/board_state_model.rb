# frozen_string_literal: true

module Discovery
  # What the probes of a board add up to (StateRules), cached in board_state.
  #
  # [state]           online, flaky, down, dead or unknown
  # [success_rate_7d] the share of successful probes in the last 7 days, nil
  #                   without a probe there
  # [failures]        the failed probes since the last success
  class BoardStateModel < Data.define(:state, :success_rate_7d, :failures)
    STATES = %w[online flaky down dead unknown].freeze
  end
end
