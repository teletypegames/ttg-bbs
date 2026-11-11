# frozen_string_literal: true

module Grafana
  module Build
    # A table: the first frame's fields as columns (those the panel hides
    # left out), each cell as its field shows it, coloured when the column
    # colours its cells (or a mapping gives a colour), sorted as the panel
    # asks.
    module Tables
      # The most rows kept.
      MAX_ROWS = 1000
      # The cell types of a column that colour its cells.
      COLORED = %w[color-text color-background color-background-solid gauge lcd-gauge gradient-gauge basic].freeze

      module_function

      # The Visual::Table of +frames+ for +panel+.
      def table(panel, frames, notes)
        frame = frames.find { |f| f.length.positive? } || frames.first
        columns = frame.fields.filter_map do |field|
          display = Build.display(panel, frame, field, base: field.number? ? Build::VALUE_BASE : {})
          [field, display] unless Build.hidden?(display)
        end
        order = sorted(panel, columns, frame.length)
        rows  = order.first(MAX_ROWS).map { |i| columns.map { |field, display| cell(field, display, field.values[i]) } }
        Visual::Table.new(columns: columns.map { |_, d| d.name }, rows: rows, tables: frames.size, notes: notes)
      end

      # A Cell of +value+ in a column.
      def cell(field, display, value)
        colored = COLORED.include?(display.custom.dig('cellOptions', 'type').to_s) ||
                  COLORED.include?(display.custom['displayMode'].to_s)
        mapped  = display.mapping(value)&.dig('color')
        color   = mapped ? Colors.rgb(mapped) : (display.color(value) if colored)
        Visual::Cell.new(text: display.text(value).tr("\n\t", '  '), color: color, numeric: field.number?)
      end

      # The rows in the panel's order (<tt>options.sortBy</tt>), else as they
      # came.
      def sorted(panel, columns, length)
        rule  = Array(panel.options['sortBy']).first
        order = (0...length).to_a
        return order unless rule.is_a?(Hash)

        field, = columns.find { |_, d| d.name == rule['displayName'].to_s }
        return order unless field

        order = order.sort_by { |i| key(field.values[i]) }
        rule['desc'] ? order.reverse : order
      end

      # A value's place in a sort.
      def key(value)
        case value
        when nil then [0, 0]
        when Numeric then [1, value.to_f.nan? ? -Float::INFINITY : value]
        else [2, value.to_s]
        end
      end
    end

    # Log lines: each frame's time and line, newest first (or as the panel
    # orders), with the level its labels or its words say.
    module Logs
      # The most lines kept.
      MAX_LINES = 1000
      # A terminal's escape sequence in a line (its colours).
      ANSI = %r{\e\[[\d;?]*[ -/]*[@-~]}
      # The names a log line's field goes by.
      LINE_NAMES = %w[Line line body message msg].freeze
      # The words of each level, looked for in a line without a level label.
      LEVELS = [
        [:error, /\b(error|err|fatal|crit(ical)?|panic|emerg|alert)\b/i], [:warn, /\bwarn(ing)?\b/i],
        [:debug, /\b(debug|trace)\b/i], [:info, /\binfo\b/i]
      ].freeze

      module_function

      # Whether +frames+ look like log lines.
      def logs?(frames)
        frames.any? { |f| f.meta.dig('custom', 'frameType') == 'LabeledTimeValues' || (f.time_field && line_field(f)) }
      end

      # The field of a frame that holds the lines.
      def line_field(frame)
        frame.fields.find { |f| LINE_NAMES.include?(f.name) && f.type == :string }
      end

      # The Visual::Logs of +frames+ for +panel+.
      def logs(panel, frames, notes)
        lines = frames.flat_map { |frame| lines_of(frame) }
        lines = lines.sort_by { |l| -l.time.to_i }
        lines = lines.reverse if panel.options['sortOrder'] == 'Ascending'
        Visual::Logs.new(lines: lines.first(MAX_LINES), notes: notes)
      end

      # The LogLines of one frame.
      def lines_of(frame)
        time   = frame.time_field
        line   = line_field(frame) || frame.fields.find { |f| f.type == :string } or return []
        labels = frame.fields.find { |f| f.name == 'labels' }
        frame.length.times.map do |i|
          tags = labels&.values&.[](i)
          tags = {} unless tags.is_a?(Hash)
          text = line.values[i].to_s.gsub(ANSI, '')
          Visual::LogLine.new(time: time&.values&.[](i), text: text, level: level(tags, text), labels: tags)
        end
      end

      # The level of a line: its label, else the words in it.
      def level(labels, text)
        named = (labels['detected_level'] || labels['level'] || labels['severity']).to_s.downcase
        return named.start_with?('warn') ? :warn : named.to_sym if %w[error warn warning info debug].include?(named)
        return :error if %w[fatal critical crit err].include?(named)

        LEVELS.find { |_, pattern| pattern.match?(text) }&.first || :unknown
      end
    end

    # States over time (a state timeline, a status history): each value
    # field a row, cut where its value changes, each stretch coloured by its
    # mapping or threshold.
    module States
      # The most rows kept.
      MAX_ROWS = 40

      module_function

      # The Visual::States of +frames+ for +panel+ over [+from+, +to+].
      def states(panel, frames, notes, from, to)
        index = -1
        rows = frames.select(&:time_field).flat_map do |frame|
          time = frame.time_field
          (frame.fields - [time]).filter_map do |field|
            index += 1
            display = Build.display(panel, frame, field, index: index, base: Build::VALUE_BASE)
            [display.name, segments(time, field, display)] unless Build.hidden?(display)
          end
        end
        Visual::States.new(rows: rows.first(MAX_ROWS), from: from, to: to, notes: notes)
      end

      # The stretches of +field+ over +time+.
      def segments(time, field, display)
        time.values.each_with_index.with_object([]) do |(at, i), list|
          next unless at

          value = field.values[i]
          text  = display.text(value)
          next if list.last&.text == text

          list << Visual::Segment.new(time: at, text: text, color: value.nil? ? nil : display.color(value))
        end
      end
    end
  end
end
