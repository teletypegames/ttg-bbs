# frozen_string_literal: true

# The file areas of the BBS, read from the FTP server: the DOS programs of
# APPS, and every catalog file in WARP, grouped by the game it belongs to.
class FileLibraryService
  AREAS = %i[apps warp].freeze

  def initialize(repo, games:)
    @repo  = repo
    @games = games
  end

  def apps = @repo.apps
  def readme(app) = @repo.text("/APPS/#{app.folder}/README.md")
  def app_url(app) = @repo.url("/APPS/#{app.folder}/")
  def warp_url(file = '') = @repo.url("/WARP/#{file}")

  # Catalog games with their WARP files, every version. A file belongs to a
  # game when its name starts with the stem of one of the game's asset
  # paths: rabbitc64 ships rabbit-1.0.0.prg.
  def warp_games
    files = @repo.warp
    @games.all.filter_map do |game|
      stems = file_stems(game)
      next if stems.empty?

      own = files.select { |f| stems.any? { |stem| f.name.match?(/\A#{Regexp.escape(stem)}-\d/) } }
      [game, own] unless own.empty?
    end
  end

  # The size in bytes of a WARP file, nil when it is not there.
  def warp_size(name) = @repo.warp.find { |f| f.name == name }&.size

  private

  def file_stems(game)
    return [] unless game.released?

    game.assets.filter_map do |asset|
      base = File.basename(asset.path)
      cut  = base.index("-#{game.version}")
      base[0, cut] if cut
    end.uniq
  end
end
