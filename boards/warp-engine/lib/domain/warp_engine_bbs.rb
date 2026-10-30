# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the catalog wired to the
# shelf list, the archive and the download log. Both faces (lib/ui/modern,
# lib/ui/petscii) work on one instance of it.
class WarpEngineBBS
  ROOT = File.expand_path('../..', __dir__)

  attr_reader :catalog

  def initialize
    shelves   = ShelfRepository.new(ENV.fetch('WARP_SHELVES', File.join(ROOT, 'config/shelves.yml')))
    archive   = ArchiveRepository.new(ENV.fetch('WARP_ARCHIVE_URL', 'http://archive.teletypegames.org'),
                                      ttl: Integer(ENV.fetch('WARP_INDEX_TTL', '300')))
    downloads = DownloadRepository.new(ENV.fetch('WARP_DOWNLOADS', File.join(ROOT, 'data/downloads.jsonl')))
    @catalog  = CatalogService.new(shelves: shelves, archive: archive, downloads: downloads,
                                   max_bytes: Integer(ENV.fetch('WARP_DOWNLOAD_MAX', (1024 * 1024).to_s)))
  end

  # The services by name.
  def services = { catalog: @catalog }
end
