# frozen_string_literal: true

class GamesService
  def initialize(repo) = @repo = repo

  def all = @repo.fetch

  def platforms = all.map(&:platform).reject(&:empty?).uniq.sort

  def by_platform(platform)
    games = all.sort_by { |g| [g.platform, g.title.downcase] }
    platform ? games.select { |g| g.platform == platform } : games
  end

  # Latest proper releases first; development builds stay out of the news.
  def latest_releases(n = 3)
    all.select { |g| g.released? && !g.dev_build? && g.released_at }
       .sort_by { |g| -g.released_at.to_i }
       .first(n)
  end

  def catalog_url(game) = @repo.catalog_url(game)
end
