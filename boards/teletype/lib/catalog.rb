# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class CatalogClient
  API_URL   = 'https://games.teletype.hu/api/software'
  GAMES_URL = 'https://games.teletype.hu'

  def fetch
    uri  = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 12
    http.read_timeout = 12
    data = JSON.parse(http.get(uri.path).body)
    data.is_a?(Hash) ? (data['softwares'] || []) : data
  rescue => e
    warn "Catalog fetch error: #{e}"
    []
  end

  def play_url(path)
    "#{GAMES_URL}#{path}"
  end
end
