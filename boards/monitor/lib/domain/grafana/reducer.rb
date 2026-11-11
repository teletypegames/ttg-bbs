# frozen_string_literal: true

module Grafana
  # Grafana's reducers (the +calcs+ of a stat, a legend or the reduce
  # transformation): one number of a field's values.
  module Reducer
    # The words of each reducer, for a legend's or a table's head.
    NAMES = {
      'lastNotNull'   => 'Last *',
      'last'          => 'Last',
      'firstNotNull'  => 'First *',
      'first'         => 'First',
      'min'           => 'Min',
      'max'           => 'Max',
      'mean'          => 'Mean',
      'median'        => 'Median',
      'sum'           => 'Total',
      'count'         => 'Count',
      'range'         => 'Range',
      'delta'         => 'Delta',
      'diff'          => 'Difference',
      'diffperc'      => 'Difference %',
      'changeCount'   => 'Change count',
      'distinctCount' => 'Distinct count',
      'stdDev'        => 'StdDev',
      'variance'      => 'Variance',
      'allIsNull'     => 'All null',
      'allIsZero'     => 'All zero',
      'logmin'        => 'Min (above zero)',
      'step'          => 'Min interval',
      'allValues'     => 'All values',
      'uniqueValues'  => 'Unique values'
    }.freeze

    module_function

    # The reducer +calc+ of +values+ (an Array; +nil+ and NaN are skipped
    # where Grafana skips them). An unknown reducer is +lastNotNull+.
    def reduce(calc, values)
      values = Array(values)
      present = values.reject { |v| v.nil? || (v.is_a?(Float) && v.nan?) }
      numbers = present.grep(Numeric)
      return percentile(numbers, calc[1..].to_f) if calc.to_s.match?(/\Ap\d+\z/)

      simple(calc.to_s, values, present, numbers)
    end

    # The reducers of a value as it is.
    def simple(calc, values, present, numbers)
      case calc
      when 'last' then values.last
      when 'first' then values.first
      when 'firstNotNull' then present.first
      when 'count' then values.size.to_f
      when 'distinctCount' then present.uniq.size.to_f
      when 'allIsNull' then present.empty?
      when 'allIsZero' then numbers.any? && numbers.all?(&:zero?)
      when 'changeCount' then present.each_cons(2).count { |a, b| a != b }.to_f
      else numeric(calc, numbers) || present.last
      end
    end

    # The reducers of numbers; +nil+ when there are none.
    def numeric(calc, numbers)
      return nil if numbers.empty? && calc != 'lastNotNull'

      case calc
      when 'min' then numbers.min
      when 'max' then numbers.max
      when 'mean', 'avg' then numbers.sum / numbers.size
      when 'sum', 'total' then numbers.sum.to_f
      when 'range' then numbers.max - numbers.min
      when 'diff' then numbers.last - numbers.first
      when 'diffperc' then numbers.first.zero? ? nil : (numbers.last - numbers.first) / numbers.first * 100
      when 'delta' then delta(numbers)
      when 'median' then percentile(numbers, 50)
      when 'variance', 'stdDev' then spread(calc, numbers)
      when 'logmin' then numbers.select(&:positive?).min
      end
    end

    # The sum of the rises, a counter's reset counted from zero.
    def delta(numbers)
      numbers.each_cons(2).sum { |a, b| b >= a ? b - a : b }.to_f
    end

    # The variance or the standard deviation.
    def spread(calc, numbers)
      mean = numbers.sum / numbers.size
      variance = numbers.sum { |n| (n - mean)**2 } / numbers.size
      calc == 'stdDev' ? Math.sqrt(variance) : variance
    end

    # The +pct+ percentile (nearest rank).
    def percentile(numbers, pct)
      return nil if numbers.empty?

      sorted = numbers.sort
      sorted[((pct / 100.0) * (sorted.size - 1)).round]
    end

    # The words of +calc+.
    def name(calc) = NAMES.fetch(calc.to_s) { calc.to_s.match?(/\Ap\d+\z/) ? "#{calc[1..]}th %" : calc.to_s }
  end
end
