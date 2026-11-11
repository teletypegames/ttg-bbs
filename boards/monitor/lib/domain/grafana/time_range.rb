# frozen_string_literal: true

module Grafana
  # The time a dashboard looks at: the last +span+ seconds up to now, as
  # Grafana's relative ranges (<tt>now-6h</tt> … <tt>now</tt>). A
  # dashboard's own range is taken when it is relative to now; anything
  # else (an absolute range, <tt>now/d</tt>) falls back to the last 6 hours.
  class TimeRange
    # The spans a caller can step through, in seconds by their name.
    PRESETS = {
      '5m'  => 300,
      '15m' => 900,
      '1h'  => 3600,
      '3h'  => 10_800,
      '6h'  => 21_600,
      '12h' => 43_200,
      '24h' => 86_400,
      '2d'  => 172_800,
      '7d'  => 604_800,
      '30d' => 2_592_000
    }.freeze
    # Seconds of each unit of a relative range.
    UNITS = { 's' => 1, 'm' => 60, 'h' => 3600, 'd' => 86_400, 'w' => 604_800, 'M' => 2_592_000, 'y' => 31_536_000 }.freeze
    # The span when the dashboard's cannot be read.
    FALLBACK = 21_600

    # The span in seconds.
    attr_reader :span

    # The last +span+ seconds.
    def initialize(span) = @span = span.to_i.clamp(60, 31_536_000)

    # The range of a dashboard's +time+ (<tt>{ 'from' => 'now-24h', 'to' => 'now' }</tt>).
    def self.of(time)
      from = time.is_a?(Hash) ? time['from'].to_s : ''
      to   = time.is_a?(Hash) ? time['to'].to_s : 'now'
      match = from.match(/\Anow-(\d+)([smhdwMy])\z/)
      new(match && to == 'now' ? match[1].to_i * UNITS.fetch(match[2]) : FALLBACK)
    end

    # The range one preset on (+step+ 1) or back (-1) from this one.
    def step(step)
      spans = PRESETS.values
      index = spans.index(@span) || spans.index { |s| s >= @span } || (spans.size - 1)
      TimeRange.new(spans[(index + step).clamp(0, spans.size - 1)])
    end

    # The name of the span (<tt>6h</tt>, <tt>90m</tt>).
    def label
      PRESETS.key(@span) || begin
        unit, size = UNITS.to_a.reverse.find { |_, s| (@span % s).zero? }
        "#{@span / size}#{unit}"
      end
    end

    # The range ending at +now+ (a Time) in epoch milliseconds: [from, to].
    def millis(now = Time.now)
      to = (now.to_f * 1000).to_i
      [to - (@span * 1000), to]
    end

    # Two ranges are the same when their spans are.
    def ==(other) = other.is_a?(TimeRange) && other.span == @span
    alias eql? ==

    # A hash by the span.
    def hash = @span.hash
  end
end
