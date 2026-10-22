# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# GET + JSON parse with short timeouts, and a small time-based cache so a
# screen redraw does not hit the remote API every time.
module HttpJson
  TTL = 300
  FAILURE_TTL = 60

  def get_json(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 12
    http.read_timeout = 12
    JSON.parse(http.get(uri.request_uri).body)
  end

  # A source that failed is not asked again for FAILURE_TTL seconds: the
  # last good answer stands meanwhile, or the failure is raised again.
  def cached(key, ttl: TTL)
    @cache_mu ||= Mutex.new
    @cache    ||= {}
    hit = @cache_mu.synchronize { @cache[key] }
    if hit && Time.now - hit[0] < ttl
      raise hit[1] if hit[1].is_a?(Exception)

      return hit[1]
    end

    begin
      value = yield
    rescue StandardError => e
      retry_at = Time.now - ttl + FAILURE_TTL
      @cache_mu.synchronize { @cache[key] = [retry_at, hit && !hit[1].is_a?(Exception) ? hit[1] : e] }
      raise
    end
    @cache_mu.synchronize { @cache[key] = [Time.now, value] }
    value
  end
end
