# frozen_string_literal: true

module Grafana
  module Build
    # Lines over time (a time series, a graph): every number field of a
    # frame with a time field is a Series, coloured as the panel says, with
    # the legend's figures.
    module Charts
      # The most series drawn; the rest are counted in a note.
      MAX_SERIES = 40

      module_function

      # The Visual::Chart of +frames+ for +panel+.
      def chart(panel, frames, notes)
        series = all_series(panel, frames)
        if series.size > MAX_SERIES
          notes += ["the #{MAX_SERIES} highest of #{series.size} series"]
          series = series.max_by(MAX_SERIES) { |s| s.points.map(&:last).max || -Float::INFINITY }
        end
        first = series.first&.look
        Visual::Chart.new(
          series:  series,
          look:    first,
          min:     first&.min,
          max:     first&.max,
          stacked: stacked?(panel),
          notes:   notes
        )
      end

      # Every Series of +frames+, in order.
      def all_series(panel, frames)
        index = -1
        frames.select(&:series?).flat_map do |frame|
          time = frame.time_field
          frame.number_fields.filter_map do |field|
            index += 1
            display = Build.display(panel, frame, field, index: index)
            next if Build.hidden?(display)

            series(panel, display, time, field)
          end
        end
      end

      # The Series of +field+ over +time+.
      def series(panel, display, time, field)
        points = time.values.each_with_index.filter_map do |at, i|
          value = field.values[i]
          [at, value] if at && value.is_a?(Numeric)
        end
        color = series_color(display, points)
        Visual::Series.new(
          name:   display.name,
          color:  color,
          points: points,
          look:   display,
          stats:  stats(panel, display, points)
        )
      end

      # A series coloured by thresholds takes the colour of its last value.
      def series_color(display, points)
        mode = display.config.dig('color', 'mode').to_s
        return display.color(points.last&.last) if mode == 'thresholds' && points.any?

        display.color(nil)
      end

      # The legend's figures of a series: [words, text] for each calc.
      def stats(panel, display, points)
        calcs = Array(panel.options.dig('legend', 'calcs')).map(&:to_s)
        values = points.map(&:last)
        calcs.map { |calc| [Reducer.name(calc), display.text(Reducer.reduce(calc, values))] }
      end

      # Whether the panel stacks its series.
      def stacked?(panel)
        mode = panel.field_config.dig('defaults', 'custom', 'stacking', 'mode').to_s
        %w[normal percent].include?(mode)
      end
    end
  end
end
