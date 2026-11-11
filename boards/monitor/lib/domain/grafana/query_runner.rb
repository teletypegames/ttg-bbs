# frozen_string_literal: true

module Grafana
  # What a panel's queries gave: the +frames+ in the order of the queries,
  # and the +errors+ (words, one a failed query).
  Result = Data.define(:frames, :errors) do
    # No frames, no errors.
    def self.empty = new(frames: [], errors: [])

    # Whether there is nothing to show.
    def empty? = frames.none? { |f| f.length.positive? }
  end

  # Runs the queries of a panel through Grafana (<tt>/api/ds/query</tt>):
  # each target with its data source, the dashboard's variables put in,
  # over the range, as many points as the screen draws.
  class QueryRunner
    # [client]      a Client
    # [datasources] the Datasources the token sees
    def initialize(client, datasources)
      @client      = client
      @datasources = datasources
    end

    # The Result of +panel+'s queries with +interpolator+ (an
    # Interpolator) over [+from+, +to+] (epoch ms) in +points+ points.
    def run(panel, interpolator, from:, to:, points:)
      interval = QueryRunner.round([(to - from) / [points, 1].max, QueryRunner.millis(panel.interval)].max)
      queries, errors = build(panel, interpolator, interval: interval, points: points)
      return Result.new(frames: [], errors: errors) if queries.empty?

      answer = @client.post('/api/ds/query', { from: from.to_s, to: to.to_s, queries: queries })
      read(answer, queries, errors)
    end

    # Runs one +query+ (a Hash of the data source's fields) on +source+
    # (a Source) over [+from+, +to+]; its frames. For a variable's query.
    def run_one(source, query, from:, to:)
      body = query.merge('refId' => 'V', 'datasource' => { 'uid' => source.uid, 'type' => source.type })
      read(@client.post('/api/ds/query', { from: from.to_s, to: to.to_s, queries: [body] }), [body], []).frames
    end

    # The steps an interval is rounded up to, in ms, as Grafana rounds them.
    STEPS = [
      10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10_000, 15_000, 20_000, 30_000, 60_000, 120_000, 300_000, 600_000,
      900_000, 1_200_000, 1_800_000, 3_600_000, 7_200_000, 10_800_000, 21_600_000, 43_200_000, 86_400_000, 604_800_000
    ].freeze

    # +ms+ rounded up to the next step of STEPS.
    def self.round(ms) = STEPS.find { |step| step >= ms } || STEPS.last

    # The milliseconds of an interval like <tt>1m</tt>, <tt>30s</tt>; 0 for
    # none.
    def self.millis(text)
      match = text.to_s.match(/\A(\d+)(ms|s|m|h|d)\z/) or return 0
      match[1].to_i * { 'ms' => 1, 's' => 1000, 'm' => 60_000, 'h' => 3_600_000, 'd' => 86_400_000 }.fetch(match[2])
    end

    private

    def build(panel, interpolator, interval:, points:)
      errors = []
      queries = panel.queries.each_with_index.filter_map do |target, i|
        target = target.merge('refId' => (target['refId'] || ('A'.ord + i).chr).to_s)
        source = source_of(panel, target, interpolator)
        unless queryable?(source)
          errors << "#{target['refId']}: no data source the board can query"
          next
        end

        body = interpolator.deep(target.except('datasource', 'hide'), type: source.type)
        body.merge(
          'datasource'    => { 'uid' => source.uid, 'type' => source.type },
          'intervalMs'    => interval,
          'maxDataPoints' => [panel.max_data_points.to_i, points].reject(&:zero?).min
        )
      end
      [queries, errors]
    end

    def source_of(panel, target, interpolator)
      ref = target['datasource']
      ref = panel.datasource if ref.nil? || (ref.is_a?(Hash) && ref['uid'].to_s.empty? && ref['type'].to_s.empty?)
      ref = nil if Datasources.mixed?(ref)
      @datasources.find(ref, interpolator)
    end

    def queryable?(source) = source && source.uid != Datasources::GRAFANA && source.type != 'datasource'

    def read(answer, queries, errors)
      results = answer['results'] || {}
      by_query = queries.map do |query|
        part = results[query['refId']] || {}
        errors << "#{query['refId']}: #{part['error']}" unless part['error'].to_s.empty?
        [query, Array(part['frames']).map { |json| Frame.of(json) }]
      end
      Result.new(frames: Tabulate.apply(by_query), errors: errors)
    end
  end
end
