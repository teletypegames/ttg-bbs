# frozen_string_literal: true

module Grafana
  # Finds the options of a dashboard's query variables, in order, each
  # with the ones before it put in (a variable may use another): label
  # values of Prometheus and Loki through their data source's resources,
  # SQL and <tt>query_result(…)</tt> through a query. A variable whose
  # options cannot be found keeps what the dashboard saved.
  class VariableResolver
    # The most options kept of one variable.
    MAX_OPTIONS = 500

    # [client]      a Client
    # [datasources] the Datasources
    # [runner]      a QueryRunner
    def initialize(client, datasources, runner)
      @client      = client
      @datasources = datasources
      @runner      = runner
    end

    # +variables+ with their options found anew over [+from+, +to+] (epoch
    # ms) for the dashboard +title+.
    def resolve(variables, from:, to:, title: '')
      variables.each_with_object([]) do |variable, done|
        done << resolved(
          variable,
          Interpolator.new(done + variables.drop(done.size), from: from, to: to, dashboard: title),
          from,
          to
        )
      end
    end

    private

    def resolved(variable, interpolator, from, to)
      return variable unless variable.type == 'query'

      source = @datasources.find(variable.datasource, interpolator) or return variable
      values = options(source, variable, interpolator, from, to)
      return variable if values.nil?

      variable.with_options(sorted(filtered(values, variable.regex), variable.sort).first(MAX_OPTIONS))
    rescue Error => e
      Rubbs.log('variable', "#{variable.name}: #{e.message}")
      variable
    end

    def options(source, variable, interpolator, from, to)
      query = variable.query
      case source.type
      when 'prometheus' then prometheus(source, interpolator.apply(text_of(query), type: 'prometheus'), from, to)
      when 'loki' then loki(source, query, interpolator, from, to)
      else sql(source, interpolator.apply(text_of(query), type: source.type), from, to)
      end
    end

    def text_of(query) = query.is_a?(Hash) ? (query['query'] || query['rawSql'] || query['expr']).to_s : query.to_s

    def prometheus(source, text, from, to)
      range = { 'start' => (from / 1000).to_s, 'end' => (to / 1000).to_s }
      case text.strip
      when /\Alabel_values\(\s*([\w.]+)\s*\)\z/ then labels(source, Regexp.last_match(1), range)
      when /\Alabel_values\((.+),\s*([\w.]+)\s*\)\z/m then labels(
        source,
        Regexp.last_match(2),
        range.merge('match[]' => Regexp.last_match(1))
      )
      when /\Alabel_names\(\s*\)\z/ then plain(get(source, 'api/v1/labels', range))
      when /\Ametrics\((.*)\)\z/ then metrics(source, Regexp.last_match(1), range)
      when /\Aquery_result\((.+)\)\z/m then query_result(source, Regexp.last_match(1), to)
      end
    end

    def labels(source, label, params) = plain(get(source, "api/v1/label/#{label}/values", params))

    def metrics(source, pattern, params)
      names = labels(source, '__name__', params)
      regexp = FieldDisplay.regexp(pattern.strip) unless pattern.strip.empty?
      regexp ? names.select { |o| regexp.match?(o.value) } : names
    end

    def query_result(source, expr, to)
      frames = @runner.run_one(source, { 'expr' => expr, 'instant' => true, 'range' => false }, from: to - 60_000, to: to)
      frames.flat_map(&:number_fields).map do |f|
        text = "#{f.labels['__name__']}{#{f.labels.except('__name__').map { |k, v| "#{k}=\"#{v}\"" }.join(',')}} #{f.values.last}"
        Option.new(text: text, value: text)
      end
    end

    def loki(source, query, interpolator, from, to)
      hash = query.is_a?(Hash) ? query : loki_query(query.to_s)
      return nil unless hash && hash['type'].to_i == 1 && !hash['label'].to_s.empty?

      params = { 'start' => (from * 1_000_000).to_s, 'end' => (to * 1_000_000).to_s }
      stream = interpolator.apply(hash['stream'].to_s, type: 'loki')
      params['query'] = stream unless stream.strip.empty?
      plain(get(source, "label/#{hash['label']}/values", params))
    end

    # A Loki variable written as <tt>label_values({stream}, label)</tt> or
    # <tt>label_values(label)</tt>.
    def loki_query(text)
      match = text.strip.match(/\Alabel_values\((?:(\{.*\})\s*,\s*)?([\w.]+)\s*\)\z/m) or return nil
      { 'type' => 1, 'stream' => match[1].to_s, 'label' => match[2] }
    end

    def sql(source, text, from, to)
      return nil if text.strip.empty?

      frames = @runner.run_one(source, { 'rawSql' => text, 'format' => 'table', 'rawQuery' => true }, from: from, to: to)
      frame = frames.first or return []
      text_field  = frame.field('__text') || frame.fields.first
      value_field = frame.field('__value') || text_field
      frame.length.times.map { |i| Option.new(text: text_field.values[i].to_s, value: value_field.values[i].to_s) }.uniq
    end

    def get(source, path, params) = @client.get("/api/datasources/uid/#{source.uid}/resources/#{path}", params)

    def plain(answer) = Array(answer.is_a?(Hash) ? answer['data'] : answer).map { |v| Option.new(text: v.to_s, value: v.to_s) }

    def filtered(options, regex)
      return options if regex.to_s.strip.empty?

      pattern = FieldDisplay.regexp(regex) or return options
      options.filter_map do |o|
        match = pattern.match(o.text) or next
        named = match.names
        text  = named.include?('text') ? match[:text] : (match[1] || o.text)
        value = named.include?('value') ? match[:value] : (match[1] || o.value)
        Option.new(text: text.to_s, value: value.to_s)
      end.uniq
    end

    def sorted(options, sort)
      case sort
      when 1, 5 then options.sort_by { |o| sort == 5 ? o.text.downcase : o.text }
      when 2, 6 then options.sort_by { |o| sort == 6 ? o.text.downcase : o.text }.reverse
      when 3 then options.sort_by { |o| o.text.to_f }
      when 4 then options.sort_by { |o| -o.text.to_f }
      else options
      end
    end
  end
end
