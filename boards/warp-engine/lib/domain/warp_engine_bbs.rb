# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to the
# shelf list, the archive and the download log. Both faces (lib/ui/modern,
# lib/ui/petscii) work on one instance of it. The only place that reads ENV.
class WarpEngineBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :catalog

  def initialize
    @catalog = CatalogService.new(shelves: shelves, archive: archive, downloads: downloads,
                                  max_bytes: Integer(env('DOWNLOAD_MAX', (1024 * 1024).to_s)))
  end

  # The services by name.
  def services = { catalog: @catalog }

  private

  def env(name, default) = ENV.fetch("WARP_ENGINE_BBS_#{name}", default)

  def path(name, default) = File.expand_path(env(name, default), ROOT)

  def shelves = ShelfRepository.new(path('SHELVES', 'config/shelves.yml'))

  def archive
    ArchiveRepository.new(env('ARCHIVE_URL', 'http://archive.teletypegames.org'),
                          ttl: Integer(env('INDEX_TTL', '300')))
  end

  # The download log in data/warp-engine.sqlite3, with the JSONL log of the
  # board before it imported on the first start.
  def downloads
    db = BBS::SQLite.new(path('DB', 'data/warp-engine.sqlite3'))
    DownloadRepository.new(db).tap do |repository|
      LegacyDownloadLog.new(File.join(File.dirname(db.path), 'downloads.jsonl'), repository).import
    end
  end
end
