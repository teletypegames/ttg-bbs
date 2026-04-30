# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative '../model/game_model'

class CatalogRepository
  API_URL   = 'https://games.teletype.hu/api/software'
  GAMES_URL = 'https://games.teletype.hu'

  def fetch
    uri  = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 12
    http.read_timeout = 12
    data    = JSON.parse(http.get(uri.path).body)
    entries = data.is_a?(Hash) ? (data['softwares'] || []) : data
    entries.filter_map { |e| GameModel.new(e) if e.is_a?(Hash) }
  rescue => e
    warn "CatalogRepository fetch error: #{e}"
    []
  end

  def play_url(path)
    "#{GAMES_URL}#{path}"
  end
end
