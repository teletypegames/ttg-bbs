# frozen_string_literal: true

require 'json'

module Grafana
  # The transformations of a panel, run on its frames in order, as
  # Grafana's front end runs them: organize, sortBy, reduce, merge,
  # joinByField, labelsToFields, extractFields, convertFieldType,
  # groupingToMatrix, filterFieldsByName, limit, seriesToRows. One the board
  # does not know is passed over and named in #skipped.
  class Transformations
    # The ids the board runs.
    KNOWN = %w[
      organize sortBy reduce merge joinByField labelsToFields extractFields convertFieldType groupingToMatrix
      filterFieldsByName limit seriesToRows renameByRegex
    ].freeze

    # The ids of the transformations passed over.
    attr_reader :skipped

    # The +list+ of a panel's transformations (Hashes of +id+ and +options+).
    def initialize(list)
      @list    = list
      @skipped = []
    end

    # +frames+ after every transformation.
    def apply(frames)
      @list.reduce(frames) do |acc, step|
        id = step['id'].to_s
        next skip(id, acc) unless KNOWN.include?(id)

        send(
          :"t_#{id.gsub(/([A-Z])/) {
            "_#{Regexp.last_match(1).downcase}"
          }}",
          acc,
          step['options'].is_a?(Hash) ? step['options'] : {}
        )
      end
    end

    private

    def skip(id, frames)
      @skipped << id
      frames
    end

    def rename(field, name) = field.with(name: name, labels: {}, config: field.config.merge('displayName' => name))

    def t_organize(frames, options)
      excluded = options['excludeByName'] || {}
      renamed  = options['renameByName'] || {}
      order    = options['indexByName'] || {}
      frames.map do |frame|
        kept = frame.fields.reject { |f| excluded[f.display_name] || excluded[f.name] }
        kept = kept.sort_by.with_index { |f, i| [order[f.display_name] || order[f.name] || (1000 + i), i] } unless order.empty?
        frame.with_fields(kept.map { |f| (to = renamed[f.display_name] || renamed[f.name]).to_s.empty? ? f : rename(f, to) })
      end
    end

    def t_sort_by(frames, options)
      sort = Array(options['sort']).first || {}
      frames.map do |frame|
        field = frame.field(sort['field'].to_s) or next frame
        order = (0...frame.length).sort_by { |i| sort_key(field.values[i]) }
        order.reverse! if sort['desc']
        reorder(frame, order)
      end
    end

    def sort_key(value)
      case value
      when nil then [0, 0]
      when Numeric then [1, value.to_f.nan? ? -Float::INFINITY : value]
      else [2, value.to_s]
      end
    end

    def reorder(frame, order) = frame.with_fields(frame.fields.map { |f| f.with(values: order.map { |i| f.values[i] }) })

    def t_limit(frames, options)
      count = (options['limitField'] || 10).to_i
      frames.map { |frame| reorder(frame, (0...[frame.length, count].min).to_a) }
    end

    def t_reduce(frames, options)
      calcs = Array(options['reducers']).map(&:to_s)
      calcs = ['lastNotNull'] if calcs.empty?
      return frames.map { |frame| reduce_fields(frame, calcs, options) } if options['mode'] == 'reduceFields'

      [series_to_rows_reduced(frames, calcs, options)]
    end

    def reduce_fields(frame, calcs, options)
      fields = frame.fields.filter_map do |f|
        next f.with(values: [f.values.last]) if f.time? && options['includeTimeField']
        next nil if f.time?
        next f.with(values: [f.values.last]) unless f.number?

        f.with(values: [Reducer.reduce(calcs.first, f.values)])
      end
      frame.with_fields(fields)
    end

    def series_to_rows_reduced(frames, calcs, options)
      numbers = frames.flat_map { |frame| frame.number_fields.map { |f| [frame, f] } }
      names = Field.new(name: 'Field', type: :string, values: numbers.map { |_, f| f.display_name })
      columns = calcs.map do |calc|
        Field.new(name: Reducer.name(calc), type: :number, values: numbers.map { |_, f| Reducer.reduce(calc, f.values) })
      end
      fields = [names, *labels_columns(numbers.map(&:last), options), *columns]
      Frame.new(fields: fields, ref_id: frames.first&.ref_id)
    end

    def labels_columns(fields, options)
      return [] unless options['labelsToFields']

      keys = fields.flat_map { |f| f.labels.keys }.uniq
      keys.map { |key| Field.new(name: key, type: :string, values: fields.map { |f| f.labels[key] }) }
    end

    def t_merge(frames, _options)
      return frames if frames.size < 2

      names = frames.flat_map { |frame| frame.fields.map(&:display_name) }.uniq
      rows = merged_rows(frames, names)
      [Frame.new(fields: merged_fields(frames, names, rows), ref_id: frames.first.ref_id)]
    end

    # The rows of +frames+ under the columns +names+, rows whose shared
    # columns agree (and whose other columns do not clash) made one.
    def merged_rows(frames, names)
      shared = names.select { |n| frames.all? { |frame| frame.field(n) } }
      frames.each_with_object([]) do |frame, rows|
        frame.length.times do |i|
          row = frame.fields.to_h { |f| [f.display_name, f.values[i]] }
          into = shared.empty? ? nil : rows.find { |r| shared.all? { |n| r[n] == row[n] } && compatible?(r, row) }
          into ? into.merge!(row.compact) : rows << row
        end
      end
    end

    def compatible?(one, other) = (one.keys & other.keys).all? { |k| one[k].nil? || other[k].nil? || one[k] == other[k] }

    def merged_fields(frames, names, rows)
      names.map do |name|
        model = frames.lazy.map { |frame| frame.field(name) }.find(&:itself)
        model.with(name: name, labels: {}, values: rows.map { |r| r[name] }, config: model.config.merge('displayName' => name))
      end
    end

    def t_join_by_field(frames, options)
      return frames if frames.size < 2

      by = options['byField'].to_s
      keyed = frames.map { |frame| [frame, by.empty? ? frame.time_field : frame.field(by)] }
      keyed = keyed.select { |_, key| key }
      return frames if keyed.size < 2

      [join(keyed, options['mode'].to_s == 'inner')]
    end

    def join(keyed, inner)
      key_field = keyed.first[1]
      keys = keyed.map { |_, key| key.values }
      all = inner ? keys.reduce(:&) : keys.flatten.uniq
      all = all.sort_by { |k| sort_key(k) }
      others = keyed.flat_map do |frame, key|
        index = key.values.each_with_index.to_h
        frame.fields.reject { |f| f.equal?(key) }.map { |f| f.with(values: all.map { |k| index[k] && f.values[index[k]] }) }
      end
      Frame.new(fields: [key_field.with(values: all), *others], ref_id: keyed.first[0].ref_id)
    end

    def t_labels_to_fields(frames, options)
      return frames.map { |frame| labels_as_rows(frame) } if options['mode'] == 'rows'

      keep = Array(options['keepLabels'])
      frames.map do |frame|
        fields = frame.fields.flat_map do |f|
          next [f] if f.labels.empty?

          labels = keep.empty? ? f.labels : f.labels.slice(*keep)
          columns = labels.map { |k, v| Field.new(name: k, type: :string, values: Array.new(f.values.size, v.to_s)) }
          value_name = options['valueLabel'] ? f.labels[options['valueLabel']].to_s : f.name
          [*columns, f.with(name: value_name, labels: {}, config: f.config.except('displayNameFromDS'))]
        end
        frame.with_fields(fields.uniq(&:name))
      end
    end

    def labels_as_rows(frame)
      labels = frame.fields.flat_map { |f| f.labels.to_a }.uniq
      frame.with_fields([
        Field.new(name: 'label', type: :string, values: labels.map(&:first)),
        Field.new(name: 'value', type: :string, values: labels.map(&:last))
      ])
    end

    def t_extract_fields(frames, options)
      frames.map do |frame|
        source = frame.field(options['source'].to_s) || frame.fields.find { |f| f.type == :string } or next frame
        parsed = source.values.map { |v| extract(v, options['format'].to_s) }
        keys = parsed.flat_map(&:keys).uniq
        added = keys.map { |k| typed_field(k, parsed.map { |h| h[k] }) }
        kept = options['replace'] ? frame.fields.select { |f| options['keepTime'] && f.time? } : frame.fields
        frame.with_fields([*kept, *added])
      end
    end

    def extract(value, format)
      return value if value.is_a?(Hash)

      text = value.to_s
      if format == 'json' || (format != 'kvp' && text.start_with?('{'))
        return JSON.parse(text).then { |h|
          h.is_a?(Hash) ? h : {}
        }
      end

      text.scan(/([\w.-]+)\s*[=:]\s*("[^"]*"|\S+)/).to_h { |k, v| [k, v.delete('"')] }
    rescue JSON::ParserError
      {}
    end

    def typed_field(name, values)
      numeric = values.compact.any? && values.compact.all? { |v| v.is_a?(Numeric) || v.to_s.match?(/\A-?\d+(\.\d+)?\z/) }
      Field.new(name: name, type: numeric ? :number : :string, values: numeric ? values.map { |v| v&.to_f } : values)
    end

    def t_convert_field_type(frames, options)
      conversions = Array(options['conversions'])
      frames.map do |frame|
        frame.with_fields(frame.fields.map do |f|
          rule = conversions.find { |c| [f.name, f.display_name].include?(c['targetField'].to_s) }
          rule ? convert(f, rule['destinationType'].to_s) : f
        end)
      end
    end

    def convert(field, type)
      case type
      when 'number' then field.with(type: :number, values: field.values.map { |v| Float(v.to_s, exception: false) })
      when 'string' then field.with(type: :string, values: field.values.map { |v| v&.to_s })
      when 'time' then field.with(type: :time, values: field.values.map { |v| Frame.time(v) })
      when 'boolean' then field.with(type: :boolean, values: field.values.map { |v| %w[true 1].include?(v.to_s) })
      else field
      end
    end

    def t_grouping_to_matrix(frames, options)
      frames.map do |frame|
        column = frame.field(options['columnField'].to_s)
        row    = frame.field(options['rowField'].to_s)
        value  = frame.field(options['valueField'].to_s)
        next frame unless column && row && value

        matrix(frame, column, row, value)
      end
    end

    def matrix(frame, column, row, value)
      rows = row.values.uniq
      cols = column.values.uniq
      cells = frame.length.times.to_h { |i| [[row.values[i], column.values[i]], value.values[i]] }
      head = Field.new(name: "#{row.display_name}\\#{column.display_name}", type: :string, values: rows.map(&:to_s))
      fields = cols.map { |c| value.with(name: c.to_s, labels: {}, values: rows.map { |r| cells[[r, c]] }, config: {}) }
      frame.with_fields([head, *fields])
    end

    def t_filter_fields_by_name(frames, options)
      include = options['include'] || {}
      names   = Array(include['names'])
      pattern = include['pattern'] && FieldDisplay.regexp(include['pattern'])
      return frames if names.empty? && pattern.nil?

      frames.map { |frame|
        frame.with_fields(frame.fields.select { |f|
          names.include?(f.display_name) || pattern&.match?(f.display_name)
        })
      }
    end

    def t_rename_by_regex(frames, options)
      pattern = FieldDisplay.regexp(options['regex']) or return frames
      to = options['renamePattern'].to_s.gsub(/\$(\d)/, '\\\\\1')
      frames.map { |frame| frame.with_fields(frame.fields.map { |f| rename(f, f.display_name.sub(pattern, to)) }) }
    end

    def t_series_to_rows(frames, _options)
      rows = frames.flat_map do |frame|
        time = frame.time_field or next []
        frame.number_fields.flat_map do |f|
          f.values.each_with_index.map { |v, i| [time.values[i], f.display_name, v] }
        end
      end
      rows.sort_by! { |t, _, _| -t.to_i }
      [Frame.new(fields: [
        Field.new(name: 'Time', type: :time, values: rows.map(&:first)),
        Field.new(name: 'Metric', type: :string, values: rows.map { |r| r[1] }),
        Field.new(name: 'Value', type: :number, values: rows.map(&:last))
      ])]
    end
  end
end
