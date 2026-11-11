# frozen_string_literal: true

module Grafana
  # One choice of a variable: the +text+ shown and the +value+ put in the
  # queries.
  Option = Data.define(:text, :value)

  # A template variable of a dashboard: its +name+, +label+, +type+
  # (+query+, +custom+, +textbox+, +constant+, +interval+, +datasource+),
  # whether several values may be chosen (+multi+) and All (+include_all+,
  # +all_value+), its +options+ and the +current+ values (<tt>$__all</tt>
  # for All), and for a query its +query+, +datasource+, +regex+ and +sort+.
  Variable = Data.define(
    :name, :label, :type, :hidden, :multi, :include_all, :all_value, :options, :current, :query, :datasource, :regex, :sort
  )

  # The methods of a Variable.
  class Variable
    # The value that means every option.
    ALL = '$__all'
    # The types the board reads; an ad hoc filter or a group-by is left out.
    TYPES = %w[query custom textbox constant interval datasource].freeze

    # A variable of the JSON +hash+, or +nil+ for a type the board does not
    # read.
    def self.of(hash)
      return nil unless hash.is_a?(Hash) && TYPES.include?(hash['type']) && !hash['name'].to_s.empty?

      new(
        name:        hash['name'].to_s,
        label:       (hash['label'] || hash['name']).to_s,
        type:        hash['type'],
        hidden:      hash['hide'].to_i == 2 || hash['type'] == 'constant',
        multi:       hash['multi'] ? true : false,
        include_all: hash['includeAll'] ? true : false,
        all_value:   hash['allValue'],
        options:     Variable.options_of(hash),
        current:     Variable.current_of(hash),
        query:       hash['query'],
        datasource:  hash['datasource'],
        regex:       hash['regex'].to_s,
        sort:        hash['sort'].to_i
      )
    end

    # The options a +custom+ or +interval+ variable lists in its query
    # (<tt>a : 1, b : 2</tt>), else those its JSON keeps.
    def self.options_of(hash)
      if %w[custom interval].include?(hash['type'])
        listed = hash['query'].to_s.split(/(?<!\\),/).map(&:strip).reject(&:empty?)
        return listed.map { |item| custom_option(item.gsub('\\,', ',')) } unless listed.empty?
      end
      Array(hash['options']).grep(Hash).map { |o| Option.new(text: o['text'].to_s, value: o['value'].to_s) }
    end

    # The option of one +item+ of a custom list: <tt>text : value</tt> or
    # the value alone.
    def self.custom_option(item)
      text, value = item.split(' : ', 2)
      Option.new(text: text.strip, value: (value || text).strip)
    end

    # The values the JSON keeps as current, an Array of Strings.
    def self.current_of(hash)
      current = hash['current'].is_a?(Hash) ? hash['current']['value'] : nil
      current = hash['query'] if current.nil? && %w[textbox constant].include?(hash['type'])
      Array(current).map(&:to_s)
    end

    # Whether every option is chosen.
    def all? = include_all && current.include?(ALL)

    # Whether a caller can change it.
    def editable? = !hidden && type != 'constant'

    # Whether the caller types it rather than choosing it.
    def typed? = type == 'textbox'

    # The values in effect: every option's when All is chosen.
    def values = all? ? options.map(&:value) : current

    # What is shown for it: All, the texts of the chosen options, or the
    # typed words.
    def shown
      return 'All' if all?

      texts = current.map { |value| options.find { |o| o.value == value }&.text || value }
      texts.empty? ? '—' : texts.join(' + ')
    end

    # The variable with +options+ found anew, keeping what was chosen when
    # it is still there, else taking the first (or All).
    def with_options(options)
      kept = current.select { |value| value == ALL || options.any? { |o| o.value == value } }
      kept = [include_all ? ALL : options.first&.value].compact if kept.empty? && !typed?
      with(options: options, current: kept)
    end

    # The variable with +values+ chosen (All alone when it is among them).
    def choose(values)
      values = Array(values).map(&:to_s)
      values = [ALL] if values.include?(ALL)
      values = values.first(1) unless multi || values == [ALL]
      with(current: values)
    end
  end
end
