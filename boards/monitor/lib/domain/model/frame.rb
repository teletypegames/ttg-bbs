# frozen_string_literal: true

require 'time'

module Grafana
  # A column of a data frame: its +name+, +type+ (+:time+, +:number+,
  # +:string+, +:boolean+, +:other+), +values+ (times in epoch
  # milliseconds, numbers as Floats, +nil+ for none), +labels+ and
  # +config+ (Grafana's field config as the data source gave it).
  Field = Data.define(:name, :type, :values, :labels, :config) do
    # A field; labels and config default to none.
    def initialize(name:, type:, values:, labels: {}, config: {}) = super

    # The name Grafana would show for it, without the panel's config: the
    # data source's (a legend format), else the labels (the one value of a
    # single label), else the name.
    def display_name
      from_ds = config['displayNameFromDS'] || config['displayName']
      return from_ds.to_s unless from_ds.to_s.empty?
      return name if labels.empty?
      return labels.values.first.to_s if labels.size == 1 && %w[Value value].include?(name)

      shown = labels.map { |k, v| "#{k}=\"#{v}\"" }.join(', ')
      %w[Value value].include?(name) ? "{#{shown}}" : "#{name} {#{shown}}"
    end

    # Whether it holds numbers.
    def number? = type == :number

    # Whether it holds times.
    def time? = type == :time

    # The values that are there (not +nil+, not NaN).
    def present = values.reject { |v| v.nil? || (v.is_a?(Float) && v.nan?) }
  end

  # A data frame: a table of Fields of the same length, from the query of
  # +ref_id+, with its +name+ and +meta+.
  Frame = Data.define(:name, :ref_id, :fields, :meta) do
    # A frame; name, ref_id and meta default to none.
    def initialize(fields:, name: nil, ref_id: nil, meta: {}) = super

    # A frame of the JSON (a frame of <tt>/api/ds/query</tt>: +schema+ and
    # +data+).
    def self.of(json)
      schema = json['schema'] || {}
      data   = json['data'] || {}
      fields = Array(schema['fields']).each_with_index.map { |f, i| Frame.field(f, Frame.column(data, i)) }
      new(name: schema['name'], ref_id: schema['refId'], fields: fields, meta: schema['meta'] || {})
    end

    # Column +index+ of +data+, the special values (NaN, ±Inf) put back.
    def self.column(data, index)
      values = Array(data.dig('values', index))
      special = data.dig('entities', index)
      return values unless special.is_a?(Hash)

      values = values.dup
      { 'NaN' => Float::NAN, 'Inf' => Float::INFINITY, 'NegInf' => -Float::INFINITY }.each do |key, value|
        Array(special[key]).each { |at| values[at] = value }
      end
      values
    end

    # The Field of the schema +json+ with +values+.
    def self.field(json, values)
      type = json['type'].to_s
      kind = { 'time' => :time, 'number' => :number, 'string' => :string, 'boolean' => :boolean }.fetch(type, :other)
      values = values.map { |v| v&.to_f } if kind == :number
      values = values.map { |v| Frame.time(v) } if kind == :time
      Field.new(name: json['name'].to_s, type: kind, values: values, labels: json['labels'] || {}, config: json['config'] || {})
    end

    # A time value as epoch milliseconds (an Integer, a numeric String or
    # an ISO 8601 time), or +nil+.
    def self.time(value)
      case value
      when Numeric, /\A\d+\z/ then value.to_i
      when String then (Time.iso8601(value).to_f * 1000).to_i
      end
    rescue ArgumentError
      nil
    end

    # Rows of the frame (the longest field's).
    def length = fields.map { |f| f.values.size }.max || 0

    # Its first time field, or +nil+.
    def time_field = fields.find(&:time?)

    # Its number fields.
    def number_fields = fields.select(&:number?)

    # Whether it is a time series: a time field and a number.
    def series? = !time_field.nil? && number_fields.any?

    # The frame with +fields+ instead.
    def with_fields(fields) = with(fields: fields)

    # Row +index+ as an Array of values.
    def row(index) = fields.map { |f| f.values[index] }

    # The field named +name+ (or showing it), or +nil+.
    def field(name) = fields.find { |f| f.name == name } || fields.find { |f| f.display_name == name }
  end
end
