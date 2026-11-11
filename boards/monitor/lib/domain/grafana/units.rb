# frozen_string_literal: true

module Grafana
  # A value as Grafana writes it in a unit (+unit+ of a field's config):
  # bytes, rates, percentages, durations, dates and the plain counts, with
  # the decimals asked for or as many as the size wants. A unit the board
  # does not know is written as a short number with the unit after it.
  module Units
    # The steps of a short number.
    SHORT = ['', ' K', ' Mil', ' Bil', ' Tri'].freeze
    # The SI prefixes upwards.
    SI = ['', ' k', ' M', ' G', ' T', ' P'].freeze
    # The binary prefixes upwards.
    IEC = ['', ' Ki', ' Mi', ' Gi', ' Ti', ' Pi'].freeze
    # The units of a rate or count, by Grafana's id: the word written after it.
    SUFFIX = {
      'reqps'      => ' req/s',
      'rps'        => ' rd/s',
      'wps'        => ' wr/s',
      'iops'       => ' io/s',
      'ops'        => ' ops/s',
      'qps'        => ' q/s',
      'cps'        => ' c/s',
      'opm'        => ' ops/min',
      'rpm'        => ' rd/min',
      'reqpm'      => ' req/min',
      'hertz'      => ' Hz',
      'celsius'    => '°C',
      'fahrenheit' => '°F',
      'kelvin'     => ' K',
      'watt'       => ' W',
      'volt'       => ' V',
      'amp'        => ' A',
      'pps'        => ' p/s',
      'lengthm'    => ' m',
      'massg'      => ' g',
      'velocityms' => ' m/s',
      'humidity'   => '%H'
    }.freeze
    # The size of each step of a duration, in seconds, and its name.
    DURATION = [[31_536_000, 'year'], [604_800, 'week'], [86_400, 'day'], [3600, 'hour'], [60, 'min'], [1, 's']].freeze
    # Seconds of the time units.
    TIME_UNITS = {
      'ns' => 1e-9,
      'µs' => 1e-6,
      'us' => 1e-6,
      'ms' => 1e-3,
      's'  => 1,
      'm'  => 60,
      'h'  => 3600,
      'd'  => 86_400
    }.freeze

    module_function

    # +value+ (a Number, or +nil+) in +unit+ with +decimals+ (+nil+:
    # by its size).
    def format(value, unit = nil, decimals = nil)
      return '—' if value.nil?
      return value.to_s unless value.is_a?(Numeric)
      if value.is_a?(Float) && !value.finite?
        return (if value.nan?
                  'NaN'
                else
                  (value.positive? ? '+Inf' : '-Inf')
                end)
      end

      formatted(value.to_f, unit.to_s, decimals)
    end

    # The number written in +unit+.
    def formatted(value, unit, decimals)
      case unit
      when '', 'none', 'string' then number(value, decimals)
      when 'short', 'locale', 'sishort' then scaled(value, 1000, SHORT, decimals)
      when 'percent' then "#{number(value, decimals)}%"
      when 'percentunit' then "#{number(value * 100, decimals)}%"
      when 'bytes', 'binbytes' then "#{scaled(value, 1024, IEC, decimals)}B"
      when 'decbytes' then "#{scaled(value, 1000, SI, decimals)}B"
      when 'bits', 'binbits' then "#{scaled(value, 1024, IEC, decimals)}b"
      when 'decbits' then "#{scaled(value, 1000, SI, decimals)}b"
      when 'Bps', 'KBs' then "#{scaled(value * (unit == 'KBs' ? 1000 : 1), 1000, SI, decimals)}B/s"
      when 'binBps', 'KiBs' then "#{scaled(value * (unit == 'KiBs' ? 1024 : 1), 1024, IEC, decimals)}B/s"
      when 'bps' then "#{scaled(value, 1000, SI, decimals)}b/s"
      when 'kbytes' then "#{scaled(value * 1024, 1024, IEC, decimals)}B"
      when 'mbytes' then "#{scaled(value * 1024 * 1024, 1024, IEC, decimals)}B"
      else other(value, unit, decimals)
      end
    end

    # The units that are not sizes: times, dates, custom words, rates.
    def other(value, unit, decimals)
      return duration(value * TIME_UNITS.fetch(unit), decimals) if TIME_UNITS.key?(unit)
      return words(value) if unit == 'dtdurations'
      return words(value / 1000.0) if unit == 'dtdurationms'
      return hms(value) if unit == 'dthms'
      return date(value, unit) if unit.start_with?('dateTime')
      return custom(value, unit, decimals) if unit.include?(':')
      return "#{scaled(value, 1000, SHORT, decimals)}#{SUFFIX[unit]}" if SUFFIX.key?(unit)

      "#{scaled(value, 1000, SHORT, decimals)} #{unit}".rstrip
    end

    # A unit of the form <tt>kind:word</tt> (+suffix+, +prefix+, +si+,
    # +count+, +currency+).
    def custom(value, unit, decimals)
      kind, word = unit.split(':', 2)
      word = word.to_s.strip
      case kind
      when 'prefix', 'currency' then "#{word}#{scaled(value, 1000, SHORT, decimals)}"
      when 'si' then "#{scaled(value, 1000, SI, decimals)}#{word}"
      else "#{scaled(value, 1000, SHORT, decimals)} #{word}"
      end
    end

    # +value+ divided by +base+ while it is that large, with the prefix of
    # the step reached.
    def scaled(value, base, steps, decimals)
      step = 0
      while value.abs >= base && step < steps.size - 1
        value /= base.to_f
        step += 1
      end
      "#{number(value, decimals)}#{steps[step]}"
    end

    # +value+ with +decimals+, or as many as its size asks (and no trailing
    # zeros then).
    def number(value, decimals = nil)
      return Kernel.format("%.#{decimals.to_i.clamp(0, 10)}f", value) unless decimals.nil?
      return value.to_i.to_s if value == value.round && value.abs < 1e15

      places = auto_places(value.abs)
      Kernel.format("%.#{places}f", value).sub(/\.?0+\z/, '')
    end

    # Decimals for a number of this size.
    def auto_places(size)
      return 0 if size >= 100
      return 1 if size >= 10
      return 2 if size >= 1

      [(-Math.log10(size)).floor + 2, 6].min
    rescue FloatDomainError, Math::DomainError
      2
    end

    # A duration of +seconds+ in the largest unit it fills.
    def duration(seconds, decimals)
      return "#{number(seconds * 1000, decimals)} ms" if seconds.abs < 1 && !seconds.zero?

      size, name = DURATION.find { |s, _| seconds.abs >= s } || DURATION.last
      "#{number(seconds / size, decimals)} #{name}"
    end

    # A duration of +seconds+ in words: its two largest units.
    def words(seconds)
      left = seconds.abs.round
      parts = DURATION.filter_map do |size, name|
        count, left = left.divmod(size)
        "#{count} #{name}#{'s' if count != 1 && name != 's'}" if count.positive?
      end
      parts.empty? ? '0 s' : "#{'-' if seconds.negative?}#{parts.first(2).join(', ')}"
    end

    # +seconds+ as h:mm:ss.
    def hms(seconds)
      total = seconds.abs.round
      Kernel.format('%<h>d:%<m>02d:%<s>02d', h: total / 3600, m: total % 3600 / 60, s: total % 60)
    end

    # An epoch time in milliseconds (or seconds, small enough) as a date.
    def date(value, unit, now: Time.now)
      at = Time.at(value > 1e11 ? value / 1000.0 : value)
      return "#{words(now - at)} ago" if unit == 'dateTimeFromNow' && at <= now
      return "in #{words(at - now)}" if unit == 'dateTimeFromNow'

      at.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
