# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to the
# shelf list, the archive and the download log.
class WarpEngineBBS
  include BBS::Domain

  setting :archive_url, 'http://archive.teletypegames.org'
  setting :index_ttl, 300
  setting :download_max, 1024 * 1024
  path    :shelves, 'config/shelves.yml'
  path    :db, 'data/warp-engine.sqlite3'

  service(:catalog) do
    CatalogService.new(shelves: ShelfRepository.new(shelves), archive: ArchiveRepository.new(archive_url, ttl: index_ttl),
                       downloads: downloads, max_bytes: download_max)
  end

  private

  # The download log, with the JSONL log of the board before it imported on
  # the first start.
  def downloads
    DownloadRepository.new(database(db)).tap do |repository|
      LegacyDownloadLog.new(File.join(File.dirname(db), 'downloads.jsonl'), repository).import
    end
  end
end
