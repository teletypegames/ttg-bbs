# frozen_string_literal: true

require 'json'

module Trophies
  # The queries of the Trophy Room through Grafana's /api/ds/query, with a
  # service account's token (the Viewer role is enough, the one Monitor BBS
  # reads with). Grafana is on the private network (http://grafana:3000 on
  # interstack), so the address is not vetted as a public one.
  class Grafana
    # What went wrong asking Grafana.
    class Error < StandardError; end

    # Seconds a query may take.
    DEADLINE = 20

    # [url]   the address of Grafana, without a trailing slash
    # [token] the service account's token; empty: not configured
    # [http]  Rubbs::Common::Web::HTTP or a stand-in (a test's)
    def initialize(url:, token:, http: Rubbs::Common::Web::HTTP)
      @url   = url.to_s.chomp('/')
      @token = token.to_s
      @http  = http
    end

    # Whether a token is set.
    def configured? = !@token.empty?

    # The rows of the SQL +sql+ on the data source +uid+: an Array of
    # Arrays, a value each column. Raises Error.
    def rows(uid, sql) = frame_rows(query(datasource: { uid: uid }, rawSql: sql, format: 'table'))

    # The value of the PromQL +expr+ now on the data source +uid+, or +nil+
    # when it has no series. Raises Error.
    def value(uid, expr) = frame_rows(query(datasource: { uid: uid }, expr: expr, instant: true)).first&.last

    private

    def query(one)
      body = JSON.generate(queries: [one.merge(refId: 'A')], from: 'now-1h', to: 'now')
      response = @http.post("#{@url}/api/ds/query", body: body, headers: headers, public_only: false, deadline: DEADLINE)
      result = parse(response.body)&.dig('results', 'A')
      raise Error, "Grafana answered #{response.status}" unless result
      raise Error, result['error'] if result['error']

      result
    rescue Rubbs::Common::Web::HTTP::Error => e
      raise Error, "Grafana cannot be reached: #{e.message}"
    end

    def parse(body)
      JSON.parse(body.to_s.dup.force_encoding(Encoding::UTF_8))
    rescue JSON::ParserError
      nil
    end

    def frame_rows(result)
      columns = result.dig('frames', 0, 'data', 'values') || []
      columns.empty? ? [] : columns.first.zip(*columns.drop(1))
    end

    def headers
      { 'Authorization' => "Bearer #{@token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
    end
  end
end
