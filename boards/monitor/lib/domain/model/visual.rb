# frozen_string_literal: true

module Grafana
  # What a panel shows, read from its data and made for a text screen.
  # Every kind has +notes+ (what could not be shown: a failed query, a
  # transformation passed over) and a +kind+.
  module Visual
    # A line of a chart: its +name+, +color+ (RGB), +points+ ([ms, value]
    # pairs, oldest first), its FieldDisplay (+look+) and the +stats+ the
    # legend asks for ([words, text] pairs).
    Series = Data.define(:name, :color, :points, :look, :stats) do
      # The last value there is, or +nil+.
      def last = points.reverse_each.find { |_, v| v.is_a?(Numeric) && !v.to_f.nan? }&.last

      # The last value as the field shows it.
      def last_text = look.text(last)
    end

    # Lines over time: +series+, the FieldDisplay of the first (+look+,
    # its unit), the axis' +min+ and +max+ when set, and +stacked+.
    Chart = Data.define(:series, :look, :min, :max, :stacked, :notes) do
      # The kind.
      def kind = :chart
    end

    # One value of a stat, gauge, bar gauge or pie: its +name+, +number+,
    # +text+ (as the field shows it), +color+ (RGB), +fraction+ of its
    # range (0–1, or +nil+) and a +spark+ of [ms, value] pairs (or none).
    Value = Data.define(:name, :number, :text, :color, :fraction, :spark)

    # Values side by side: +values+, +style+ (+:stat+, +:gauge+, +:bars+,
    # +:pie+) and whether the names are shown (+names+).
    Values = Data.define(:values, :style, :names, :notes) do
      # The kind.
      def kind = :values
    end

    # A cell of a table: its +text+, +color+ (RGB or +nil+), whether it is
    # a number (+numeric+, set to the right).
    Cell = Data.define(:text, :color, :numeric)

    # A table: its +columns+ (names), +rows+ (Arrays of Cells) and how many
    # +frames+ it is the first of.
    Table = Data.define(:columns, :rows, :tables, :notes) do
      # The kind.
      def kind = :table
    end

    # A line of a log: its +time+ (ms), +text+, +level+ (a Symbol:
    # +:error+, +:warn+, +:info+, +:debug+, +:unknown+) and +labels+.
    LogLine = Data.define(:time, :text, :level, :labels)

    # Log lines, newest first unless the panel asks otherwise.
    Logs = Data.define(:lines, :notes) do
      # The kind.
      def kind = :logs
    end

    # A stretch of one state: from +time+ (ms), its +text+ and +color+.
    Segment = Data.define(:time, :text, :color)

    # States over time: rows of [name, Segments], over [+from+, +to+] (ms).
    States = Data.define(:rows, :from, :to, :notes) do
      # The kind.
      def kind = :states
    end

    # An alert rule: its +name+, +state+ (+firing+, +pending+, +normal+ …),
    # +health+, +group+ and the time it became so (+since+, ms or +nil+).
    Rule = Data.define(:name, :state, :health, :group, :since)

    # The alert rules (an alert list panel).
    Alerts = Data.define(:rules, :notes) do
      # The kind.
      def kind = :alerts
    end

    # Words: a text panel, or what the board says instead of a panel
    # (+level+: +:text+, +:empty+, +:error+).
    Text = Data.define(:text, :level, :notes) do
      # The kind.
      def kind = :text
    end
  end
end
