# frozen_string_literal: true

module Grafana
  # How one field of a panel is shown: the panel's field config (its
  # defaults, then each override whose matcher takes the field) read as the
  # unit, decimals, min and max, thresholds, value mappings, colour mode and
  # the name. #text writes a value, #color colours it.
  class FieldDisplay
    # The panel's merged config of the field (a Hash, Grafana's keys).
    attr_reader :config
    # The name shown for the field.
    attr_reader :name

    # The display of +field+ (a Field) of the frame of +ref_id+ in a panel
    # whose fieldConfig is +field_config+; +index+ is the field's place
    # among the series (its colour in the classic palette); +base+ is what
    # the panel's type takes when its config does not say (Grafana's
    # defaults: a stat is coloured by thresholds, green and red from 80).
    def initialize(field_config, field, ref_id: nil, index: 0, base: {})
      @field  = field
      @index  = index
      @config = base.merge(FieldDisplay.merged(field_config, field, ref_id)) { |_, low, high| high.nil? ? low : high }
      @name   = @config['displayName'].to_s.empty? ? field.display_name : @config['displayName'].to_s
    end

    # The panel's defaults with every matching override's properties over
    # them.
    def self.merged(field_config, field, ref_id)
      config = deep_copy(field_config['defaults'] || {})
      Array(field_config['overrides']).each do |override|
        next unless override.is_a?(Hash) && matches?(override['matcher'] || {}, field, ref_id)

        Array(override['properties']).each { |p| set(config, p['id'].to_s, p['value']) if p.is_a?(Hash) }
      end
      config
    end

    # Whether the override +matcher+ takes +field+.
    def self.matches?(matcher, field, ref_id)
      options = matcher['options']
      case matcher['id']
      when 'byName' then [field.display_name, field.name].include?(options.to_s)
      when 'byNames' then Array(options.is_a?(Hash) ? options['names'] : options).intersect?([field.display_name, field.name])
      when 'byRegexp' then regexp(options)&.match?(field.display_name) || false
      when 'byType' then field.type.to_s == options.to_s
      when 'byFrameRefID' then ref_id.to_s == options.to_s
      else false
      end
    end

    # A Regexp of Grafana's +pattern+ (<tt>/…/i</tt> or plain), or +nil+.
    def self.regexp(pattern)
      text = pattern.to_s
      match = text.match(%r{\A/(.*)/([a-z]*)\z})
      if match
        Regexp.new(match[1], match[2].include?('i') ? Regexp::IGNORECASE : nil)
      else
        Regexp.new(text)
      end
    rescue RegexpError
      nil
    end

    # Sets the dotted +path+ (<tt>custom.width</tt>) of +config+ to +value+.
    def self.set(config, path, value)
      keys = path.split('.')
      last = keys.pop
      keys.reduce(config) { |hash, key| hash[key].is_a?(Hash) ? hash[key] : (hash[key] = {}) }[last] = value
    end

    # A copy of +hash+ whose Hashes are new.
    def self.deep_copy(hash) = hash.to_h { |k, v| [k, v.is_a?(Hash) ? deep_copy(v) : v] }

    # The unit.
    def unit = @config['unit']

    # The decimals asked for, or +nil+.
    def decimals = @config['decimals']

    # The minimum and maximum set, Floats or +nil+.
    def min = number(@config['min'])

    # The maximum set.
    def max = number(@config['max'])

    # The words for no value.
    def no_value = @config['noValue'].to_s

    # The custom part of the config (the panel type's own).
    def custom = @config['custom'].is_a?(Hash) ? @config['custom'] : {}

    # +value+ as the field shows it: the mapping's text, else the value in
    # its unit.
    def text(value)
      mapped = mapping(value)
      return mapped['text'].to_s if mapped && !mapped['text'].to_s.empty?
      return (no_value.empty? ? '—' : no_value) if value.nil?
      return Units.format(value, 'dateTimeAsIso') if @field.time?
      return value.to_s unless value.is_a?(Numeric)

      Units.format(value, unit, decimals)
    end

    # The colour (RGB) of +value+: a mapping's, else by the colour mode:
    # the threshold it reaches, the fixed colour, or the series' colour in
    # the palette. +low+ and +high+ are the range a percentage threshold
    # is of.
    def color(value, low: nil, high: nil)
      mapped = mapping(value)
      return Colors.rgb(mapped['color']) if mapped && mapped['color']

      mode = @config.dig('color', 'mode').to_s
      return Colors.rgb(@config.dig('color', 'fixedColor')) || series_color if %w[fixed shades].include?(mode)
      return threshold_color(value, low, high) || series_color if mode == 'thresholds' || (mode.empty? && thresholds?)

      series_color
    end

    # The colour the series takes when nothing else colours it.
    def series_color
      fixed = @config.dig('color', 'fixedColor')
      Colors.rgb(fixed) || Colors.classic(@index)
    end

    # Whether the config has thresholds with a step over the base.
    def thresholds? = steps.size > 1

    # The thresholds' steps: [value or nil for the base, colour], lowest
    # first.
    def steps
      @steps ||= Array(@config.dig('thresholds', 'steps')).grep(Hash).map do |s|
        [number(s['value']), s['color']]
      end
    end

    # The colour of the threshold +value+ reaches, or +nil+.
    def threshold_color(value, low = nil, high = nil)
      return nil unless value.is_a?(Numeric) && steps.any?

      at = value.to_f
      at = percent_of(at, low, high) if @config.dig('thresholds', 'mode') == 'percentage'
      reached = steps.select { |limit, _| limit.nil? || at >= limit }.last || steps.first
      Colors.rgb(reached[1])
    end

    # The value mapping's result for +value+ (a Hash: +text+, +color+), or
    # +nil+.
    def mapping(value)
      Array(@config['mappings']).each do |m|
        next unless m.is_a?(Hash)

        found = Mappings.result(m, value)
        return found if found
      end
      nil
    end

    private

    def percent_of(value, low, high)
      low  = min || low || 0.0
      high = max || high || 100.0
      high == low ? 0.0 : (value - low) / (high - low) * 100
    end

    def number(value)
      Float(value)
    rescue ArgumentError, TypeError
      nil
    end
  end

  # Grafana's value mappings: a value's text and colour by its value, a
  # range, a pattern or a special case (null, NaN, true, false, empty).
  module Mappings
    module_function

    # The result (+text+, +color+) of mapping +m+ for +value+, or +nil+.
    def result(map, value)
      options = map['options'] || {}
      case map['type']
      when 'value' then value_result(options, value)
      when 'range' then range_result(options, value)
      when 'regex' then regex_result(options, value)
      when 'special' then special_result(options, value)
      end
    end

    # A mapping of exact values.
    def value_result(options, value)
      return nil if value.nil? || !options.is_a?(Hash)

      key = value.is_a?(Float) && value == value.round ? value.to_i.to_s : value.to_s
      options[key]
    end

    # A mapping of a range.
    def range_result(options, value)
      return nil unless value.is_a?(Numeric)

      from = options['from']
      to   = options['to']
      inside = (from.nil? || value >= from.to_f) && (to.nil? || value <= to.to_f)
      inside ? options['result'] : nil
    end

    # A mapping of a pattern.
    def regex_result(options, value)
      pattern = FieldDisplay.regexp(options['pattern']) or return nil
      pattern.match?(value.to_s) ? options['result'] : nil
    end

    # A mapping of a special case.
    def special_result(options, value)
      hit = case options['match']
            when 'null' then value.nil?
            when 'nan' then value.is_a?(Float) && value.nan?
            when 'null+nan' then value.nil? || (value.is_a?(Float) && value.nan?)
            when 'true' then value == true
            when 'false' then value == false
            when 'empty' then value.to_s.empty?
            end
      hit ? options['result'] : nil
    end
  end
end
