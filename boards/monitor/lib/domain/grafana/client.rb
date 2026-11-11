# frozen_string_literal: true

require 'json'
require 'uri'

module Grafana
  # What went wrong asking Grafana, in words a caller may read.
  class Error < StandardError; end

  # The HTTP API of one Grafana, read with a service account's token (the
  # Viewer role is enough): the search, the dashboards, the data sources'
  # queries and resources, the alert rules. Grafana is on the private network
  # (http://grafana:3000 on interstack), so the address is not vetted as a
  # public one.
  class Client
    # Seconds a request may take, redirects and all.
    DEADLINE = 25
    # The largest answer read (a query of many series).
    MAX_BYTES = 16 * 1024 * 1024

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

    # GET +path+ with the +params+ (a Hash, an Array value repeats the
    # name); the parsed JSON. Raises Error.
    def get(path, params = {})
      call { @http.get(address(path, params), headers: headers, **LIMITS) }
    end

    # POST +body+ (made JSON) to +path+; the parsed JSON. An answer that is
    # not 2xx but carries +results+ (a query with an error in one of its
    # parts) is returned as it is. Raises Error.
    def post(path, body)
      call do
        @http.post(
          address(path, {}),
          body:    JSON.generate(body),
          headers: headers.merge('Content-Type' => 'application/json'),
          **LIMITS
        )
      end
    end

    # The options of every request.
    LIMITS = { public_only: false, open_timeout: 5, read_timeout: 20, deadline: DEADLINE, max_bytes: MAX_BYTES }.freeze

    private

    def call
      raise Error, 'Grafana has no token set (MONITOR_BBS_GRAFANA_TOKEN)' unless configured?

      answer(yield)
    rescue Rubbs::Common::Web::HTTP::Error => e
      raise Error, "Grafana cannot be reached: #{e.message}"
    end

    def answer(response)
      data = parse(response.body)
      return data if response.ok? || (data.is_a?(Hash) && data.key?('results'))

      raise Error, refusal(response.status, data)
    end

    def parse(body)
      JSON.parse(body.to_s.dup.force_encoding('UTF-8'))
    rescue JSON::ParserError
      nil
    end

    def refusal(status, data)
      words = data.is_a?(Hash) ? (data['message'] || data['error']).to_s : ''
      case status
      when 401 then 'Grafana refused the token (401)'
      when 403 then "Grafana does not let the token see this (403)#{": #{words}" unless words.empty?}"
      when 404 then 'Grafana has no such thing (404)'
      else "Grafana answered #{status}#{": #{words}" unless words.empty?}"
      end
    end

    def headers = { 'Authorization' => "Bearer #{@token}", 'Accept' => 'application/json' }

    def address(path, params)
      query = URI.encode_www_form(params.flat_map { |k, v| Array(v).map { |one| [k, one] } })
      "#{@url}#{path}#{"?#{query}" unless query.empty?}"
    end
  end
end
