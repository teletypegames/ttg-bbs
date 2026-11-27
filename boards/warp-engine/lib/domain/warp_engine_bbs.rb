# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to the
# directory list, the archive and the download log.
class WarpEngineBBS
  include Rubbs::Common::Board::Domain

  setting :archive_url, 'http://archive.teletypegames.org'
  setting :index_ttl, 300
  setting :download_max, 1024 * 1024
  path    :directories, 'config/directories.yml'
  path    :db, 'data/warp-engine.sqlite3'
  database :db, MIGRATIONS

  service(:catalog) do
    import_legacy_log
    CatalogService.new(
      directories: DirectoryRepository.new(directories),
      archive:     ArchiveRepository.new(archive_url, ttl: index_ttl),
      max_bytes:   download_max
    )
  end

  private

  # The JSONL download log of the board before SQLite, imported on the
  # first start.
  def import_legacy_log = LegacyDownloadLog.new(File.join(File.dirname(db), 'downloads.jsonl')).import
end
