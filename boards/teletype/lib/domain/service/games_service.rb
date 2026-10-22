# frozen_string_literal: true

class GamesService
  PLATFORM_NAMES = {
    'c64'        => 'Commodore 64',
    'plus4'      => 'Commodore Plus/4',
    'tic80'      => 'TIC-80',
    'ebitengine' => 'Ebitengine',
    'godot'      => 'Godot',
    'love'       => 'LÖVE',
    'phaser'     => 'Phaser',
    'bevy'       => 'Bevy'
  }.freeze

  def self.platform_name(platform) = PLATFORM_NAMES.fetch(platform, platform.to_s.capitalize)

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

  # Every proper release of every game, newest first: the board's history.
  # [[game, release], ...]
  def release_history
    all.flat_map { |g| g.releases.map { |r| [g, r] } }
       .reject { |_, r| r.version.start_with?('dev-') || r.released_at.nil? }
       .sort_by { |_, r| -r.released_at.to_i }
  end

  def top_downloads(n = 10) = all.reject(&:dev_build?).sort_by { |g| [-g.downloads, g.title] }.first(n)
end
