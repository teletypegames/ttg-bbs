# frozen_string_literal: true

module Grafana
  module Build
    # Single values (a stat, a gauge, a bar gauge, a pie, a bar chart): each
    # number field reduced to one value by the panel's calculation, or with
    # <tt>values: true</tt> every row a value; coloured by its thresholds
    # and mappings, set in its range.
    module Values
      # The most values shown.
      MAX_VALUES = 200

      module_function

      # The Visual::Values of +frames+ for +panel+ in +style+.
      def values(panel, frames, notes, style)
        reduce = panel.options['reduceOptions'] || {}
        list = reduce['values'] ? rows(panel, frames, reduce) : reduced(panel, frames, reduce, style)
        list = ranged(list, style)
        list = pie(list) if style == :pie
        Visual::Values.new(values: list.first(MAX_VALUES), style: style, names: names?(panel, list), notes: notes)
      end

      # One value a number field, reduced by the panel's calculation.
      def reduced(panel, frames, reduce, style)
        calc  = Array(reduce['calcs']).first || 'lastNotNull'
        index = -1
        frames.flat_map do |frame|
          fields(frame, reduce['fields']).filter_map do |field|
            index += 1
            display = Build.display(panel, frame, field, index: index, base: style == :pie ? {} : VALUE_BASE)
            next if Build.hidden?(display)

            value(display, display.name, Reducer.reduce(calc, field.values), spark(frame, field))
          end
        end
      end

      # One value a row of each number field, named by the row's words.
      def rows(panel, frames, reduce)
        limit = (reduce['limit'] || MAX_VALUES).to_i
        frames.flat_map do |frame|
          words  = frame.fields.reject { |f| f.number? || f.time? }
          number = fields(frame, reduce['fields'])
          frame.length.times.first(limit).flat_map do |i|
            label = words.map { |f| f.values[i].to_s }.reject(&:empty?).join(' ')
            number.map do |field|
              display = Build.display(panel, frame, field, base: VALUE_BASE)
              name = [label, (display.name if number.size > 1 || label.empty?)].compact.reject(&:empty?).join(' ')
              value(display, name, field.values[i], [])
            end
          end
        end
      end

      # The number fields a stat shows: those matching +pattern+
      # (<tt>/^Value$/</tt> or a name), else every number field.
      def fields(frame, pattern)
        text = pattern.to_s
        return frame.number_fields if text.empty? || text == 'numeric'
        return frame.fields.reject(&:time?) if text == '/.*/'

        regexp = FieldDisplay.regexp(text)
        frame.fields.select { |f| f.name == text || f.display_name == text || regexp&.match?(f.display_name) }
      end

      # A value to show: its look (a FieldDisplay), name, number and
      # spark, made a Visual::Value by #ranged.
      Raw = Data.define(:look, :name, :number, :spark)

      # A Raw value of +number+ shown by +display+.
      def value(display, name, number, spark)
        Raw.new(look: display, name: name, number: number.is_a?(Numeric) ? number.to_f : number, spark: spark)
      end

      # The [ms, value] pairs of +field+ for a sparkline, when the frame has
      # times.
      def spark(frame, field)
        time = frame.time_field or return []
        return [] if frame.length < 3

        time.values.zip(field.values).select { |at, v| at && v.is_a?(Numeric) }
      end

      # The Visual::Values of +list+ (Raw values) with their colour and
      # fraction of the range: the field's min and max when set, the unit's
      # (percent) or the values' own.
      def ranged(list, style)
        numbers = list.map(&:number).grep(Numeric)
        list.map do |raw|
          number = raw.number.is_a?(Numeric) ? raw.number : nil
          low, high = numbers.empty? ? [0.0, 0.0] : bounds(raw.look, numbers, style)
          Visual::Value.new(
            name:     raw.name,
            number:   raw.number,
            text:     raw.look.text(raw.number),
            color:    raw.look.color(raw.number, low: low, high: high),
            fraction: number && high > low ? ((number - low) / (high - low)).clamp(0.0, 1.0) : nil,
            spark:    raw.spark
          )
        end
      end

      # The [min, max] of a value's range.
      def bounds(display, numbers, style)
        unit_range = { 'percent' => [0.0, 100.0], 'percentunit' => [0.0, 1.0] }[display.unit.to_s]
        low  = display.min || unit_range&.first || [numbers.min, 0.0].min
        high = display.max || unit_range&.last || (style == :gauge && numbers.max <= 100 ? 100.0 : numbers.max)
        [low, high]
      end

      # A pie's values: each one's share of the whole as its fraction.
      def pie(list)
        total = list.map(&:number).grep(Numeric).sum
        list.map { |v| v.with(fraction: total.positive? && v.number.is_a?(Numeric) ? v.number / total : nil) }
      end

      # Whether the names are shown (Grafana's text mode).
      def names?(panel, list)
        case panel.options['textMode'].to_s
        when 'value', 'none' then false
        when 'name', 'value_and_name' then true
        else list.size > 1 || panel.type != 'stat'
        end
      end

      # A bar chart: each row of the category field a bar of each number
      # field.
      def barchart(panel, frames, notes)
        frame = frames.first
        x = frame.field(panel.options['xField'].to_s) || frame.fields.find { |f| !f.number? } || frame.fields.first
        numbers = frame.number_fields - [x]
        list = frame.length.times.first(MAX_VALUES).flat_map do |i|
          numbers.each_with_index.map do |field, n|
            display = Build.display(panel, frame, field, index: n)
            name = numbers.size > 1 ? "#{display_x(x, i)} #{display.name}" : display_x(x, i)
            value(display, name, field.values[i], [])
          end
        end
        Visual::Values.new(values: ranged(list, :bars), style: :bars, names: true, notes: notes)
      end

      # The category of row +i+.
      def display_x(field, index)
        value = field.values[index]
        field.time? && value ? Time.at(value / 1000.0).strftime('%m-%d %H:%M') : value.to_s
      end
    end
  end
end
