# frozen_string_literal: true

require_relative 'http_json'
require_relative '../model/game_model'

class CatalogRepository
  include HttpJson

  API_URL  = 'https://teletypegames.org/api/software'
  SITE_URL = 'https://teletypegames.org'
  MAX_PAGES = 20

  def fetch
    cached(:all) do
      games = []
      page  = 1
      loop do
        data = get_json(API_URL, page: page)
        games.concat((data['softwares'] || []).filter_map { |e| GameModel.new(e) if e.is_a?(Hash) })
        page = data['nextPage']
        break if page.nil? || page > MAX_PAGES
      end
      games
    end
  rescue => e
    warn "CatalogRepository fetch error: #{e}"
    []
  end

  def catalog_url(game) = "#{SITE_URL}/catalog/#{game.name}"
end
