# frozen_string_literal: true

module Grafana
  # The table of Prometheus and Loki queries whose format is +table+, made
  # as Grafana's front end makes it (their back ends answer with a frame a
  # series): one row a point, the time, every label a column, and the
  # value; the values of several such queries side by side in
  # <tt>Value #A</tt>, <tt>Value #B</tt>, their rows joined by time and
  # labels.
  module Tabulate
    # The data sources whose table format is made here.
    SOURCES = %w[prometheus loki].freeze

    module_function

    # +frames_by_query+ ([query, frames] pairs, in order) with the frames
    # of each table query made one table, those of several table queries
    # joined into one.
    def apply(frames_by_query)
      tables = frames_by_query.select { |query, _| table?(query) }
      return frames_by_query.flat_map(&:last) if tables.empty?

      named = tables.size > 1
      rows  = tables.flat_map { |query, frames| rows_of(frames, named ? "Value ##{query['refId']}" : 'Value') }
      others = frames_by_query.reject { |query, _| table?(query) }.flat_map(&:last)
      [table(rows, tables.map { |q, _| named ? "Value ##{q['refId']}" : 'Value' }, tables.first[0]['refId']), *others]
    end

    # Whether +query+ asks for a table of a source made here.
    def table?(query) = query['format'] == 'table' && SOURCES.include?(query.dig('datasource', 'type'))

    # The rows of +frames+: [time, labels, value column, value].
    def rows_of(frames, column)
      frames.flat_map do |frame|
        time = frame.time_field
        frame.number_fields.flat_map do |field|
          field.values.each_with_index.map { |value, i| [time&.values&.[](i), field.labels, column, value] }
        end
      end
    end

    # The frame of +rows+ with the value +columns+, the rows of the same
    # time and labels made one.
    def table(rows, columns, ref_id)
      keys   = rows.flat_map { |_, labels, _, _| labels.keys }.uniq.sort
      merged = rows.each_with_object({}) do |(time, labels, column, value), acc|
        (acc[[time, labels]] ||= {})[column] = value
      end
      fields = [Field.new(name: 'Time', type: :time, values: merged.keys.map(&:first))]
      keys.each { |k| fields << Field.new(name: k, type: :string, values: merged.keys.map { |(_, l)| l[k] }) }
      columns.each { |c| fields << Field.new(name: c, type: :number, values: merged.values.map { |v| v[c] }) }
      Frame.new(fields: fields, ref_id: ref_id)
    end
  end
end
