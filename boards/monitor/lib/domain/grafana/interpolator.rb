# frozen_string_literal: true

require 'json'
require 'uri'

module Grafana
  # Puts the values of a dashboard's variables into a query, as Grafana's
  # front end does before it sends one: <tt>$name</tt>, <tt>${name}</tt>,
  # <tt>${name:format}</tt>, <tt>[[name]]</tt>, and <tt>$__from</tt>,
  # <tt>$__to</tt>, <tt>$__dashboard</tt>. A variable of several values
  # (or All) is written the way the data source reads it: a regex
  # alternation for Prometheus and Loki, quoted and joined by commas for
  # SQL. The other <tt>$__</tt> names (<tt>$__rate_interval</tt>,
  # <tt>$__timeFilter</tt> …) are left to Grafana's back end.
  class Interpolator
    # A variable in a text: $name, ${name}, ${name:format}, ${name.field}, [[name]], [[name:format]].
    PATTERN = /\$(\w+)|\[\[([\w.]+?)(?::(\w+))?\]\]|\$\{(\w+)(?:\.([^:^}]+))?(?::([^}]+))?\}/
    # The data source types whose queries are PromQL or LogQL.
    PROMQL = %w[prometheus loki].freeze
    # The data source types whose queries take SQL.
    SQL = %w[mysql postgres grafana-postgresql-datasource mssql sqlite frser-sqlite-datasource clickhouse].freeze

    # [variables] the dashboard's Variables
    # [from, to]  the range in epoch milliseconds
    # [dashboard] the dashboard's title
    def initialize(variables, from:, to:, dashboard: '')
      @variables = variables.to_h { |v| [v.name, v] }
      @builtins  = { '__from' => from.to_s, '__to' => to.to_s, '__dashboard' => dashboard.to_s }
    end

    # +text+ with the variables put in for a data source of +type+.
    def apply(text, type: nil)
      text.to_s.gsub(PATTERN) do
        match = Regexp.last_match
        name  = match[1] || match[2] || match[4]
        value(name, match[3] || match[6], type) || match[0]
      end
    end

    # Every String in +object+ (a target: Hashes and Arrays) put through
    # #apply, the data source's +uid+ and +type+ left alone.
    def deep(object, type: nil)
      case object
      when String then apply(object, type: type)
      when Array  then object.map { |item| deep(item, type: type) }
      when Hash   then object.to_h { |k, v| [k, %w[datasource refId].include?(k) ? v : deep(v, type: type)] }
      else object
      end
    end

    private

    def value(name, format, type)
      return @builtins[name] if @builtins.key?(name)

      variable = @variables[name] or return nil
      return variable.all_value.to_s if variable.all? && !variable.all_value.to_s.empty? && format.nil?

      values = variable.values
      return texts(variable).join(' + ') if format == 'text'

      format ||= default_format(variable, type)
      return promql_regex(values) if format == 'regex' && PROMQL.include?(type)

      formatted(values, format)
    end

    # A regex alternation inside a PromQL or LogQL string: its specials
    # escaped with two backslashes, as Grafana writes them.
    def promql_regex(values)
      escaped = values.map { |v| v.gsub('\\', '\\' * 4).gsub(/[$^*{}\[\]'+?.()|]/) { |c| "\\\\#{c}" } }
      escaped.size == 1 ? escaped.first : "(#{escaped.join('|')})"
    end

    def texts(variable) = variable.values.map { |v| variable.options.find { |o| o.value == v }&.text || v }

    def default_format(variable, type)
      several = variable.multi || variable.include_all
      return several ? 'sqlstring' : 'raw' if SQL.include?(type)
      return 'regex' if several

      'raw'
    end

    def formatted(values, format)
      case format
      when 'regex' then values.size == 1 ? Regexp.escape(values.first) : "(#{values.map { |v| Regexp.escape(v) }.join('|')})"
      when 'pipe' then values.join('|')
      when 'sqlstring', 'singlequote' then values.map { |v| "'#{v.gsub("'", "''")}'" }.join(',')
      when 'doublequote' then values.map { |v| "\"#{v.gsub('"', '\\"')}\"" }.join(',')
      when 'json' then JSON.generate(values.size == 1 ? values.first : values)
      when 'glob' then values.size == 1 ? values.first : "{#{values.join(',')}}"
      when 'lucene' then values.size == 1 ? values.first : "(#{values.map { |v| "\"#{v}\"" }.join(' OR ')})"
      when 'percentencode' then URI.encode_www_form_component(values.join(','))
      when 'queryparam' then values.map { |v| "var-#{URI.encode_www_form_component(v)}" }.join('&')
      else values.join(',')
      end
    end
  end
end
