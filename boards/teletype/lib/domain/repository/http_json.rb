# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# GET + JSON parse with short timeouts, and a small time-based cache so a
# screen redraw does not hit the remote API every time.
module HttpJson
  TTL = 300

  def get_json(url, params = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) unless params.empty?
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 12
    http.read_timeout = 12
    JSON.parse(http.get(uri.request_uri).body)
  end

  def cached(key, ttl: TTL)
    @cache_mu ||= Mutex.new
    @cache    ||= {}
    hit = @cache_mu.synchronize { @cache[key] }
    return hit[1] if hit && Time.now - hit[0] < ttl

    value = yield
    @cache_mu.synchronize { @cache[key] = [Time.now, value] }
    value
  end
end
