# frozen_string_literal: true

require_relative 'http_json'
require_relative '../model/game_model'

# The game catalog of teletypegames.org, every page of it, kept five
# minutes.
class CatalogRepository
  API_URL   = 'https://teletypegames.org/api/software'
  SITE_URL  = 'https://teletypegames.org'
  MAX_PAGES = 20
  TTL       = 300

  def initialize
    @cache = HttpJson::Cache.new(ttl: TTL)
  end

  # Every game of the catalog. Raises Rubbs::Common::Web::HTTP::Error (or the error of a
  # broken answer) when the site fails.
  def fetch = @cache.fetch(:all) { pages }

  def catalog_url(game) = "#{SITE_URL}/catalog/#{game.name}"

  private

  def pages
    games = []
    page  = 1
    while page && page <= MAX_PAGES
      data = HttpJson.get(API_URL, page: page)
      games.concat((data['softwares'] || []).filter_map { |e| GameModel.new(e) if e.is_a?(Hash) })
      page = data['nextPage']
    end
    games
  end
end
