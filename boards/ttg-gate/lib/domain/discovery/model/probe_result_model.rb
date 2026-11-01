# frozen_string_literal: true

module Discovery
  # The outcome of one call to a board (TelnetProbe, or a dial of the Gate).
  #
  # [result]     ok (a banner came), silent (connected, nothing came), closed
  #              (hung up at once), refused, timeout or dns_fail
  # [at]         when, epoch seconds
  # [latency_ms] the TCP connect time, nil without a connection
  # [ip]         the address called, nil when the name did not resolve
  # [banner]     the first bytes the board sent (at most 4 KB), telnet commands
  #              removed; binary
  # [options]    the telnet options the board asked for or offered, as
  #              "DO TTYPE", "WILL ECHO", …
  # [duration_ms] the whole call, DNS to hang-up; nil when not measured (a
  #              dial)
  class ProbeResultModel < Data.define(:result, :at, :latency_ms, :ip, :banner, :options, :duration_ms)
    RESULTS   = %w[ok silent closed refused timeout dns_fail].freeze
    SUCCESSES = %w[ok silent].freeze

    def initialize(result:, at:, latency_ms: nil, ip: nil, banner: ''.b, options: [], duration_ms: nil)
      raise ArgumentError, "unknown probe result #{result}" unless RESULTS.include?(result)

      super
    end

    def success? = SUCCESSES.include?(result)
  end
end
