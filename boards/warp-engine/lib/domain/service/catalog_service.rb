# frozen_string_literal: true

require 'zlib'

# The board's file area: the shelves, their titles, and a title's bytes for
# a download, but only when they are the ones its index line promises.
class CatalogService
  def initialize(shelves:, archive:, downloads:, max_bytes:)
    @shelves   = shelves
    @archive   = archive
    @downloads = downloads
    @max_bytes = max_bytes
  end

  def shelves = @shelves.all

  # The titles of +shelf+; nil when the archive does not answer.
  def titles(shelf, fresh: false) = @archive.titles(shelf, fresh: fresh)

  # The archive's address of a shelf or a title.
  def url(item) = @archive.url(item.path)

  def downloads(title) = @downloads.count(title.key)

  # The bytes of +title+, or why not: :too_big, :unavailable (the archive
  # did not give them), :changed (not the size or CRC-32 of the index line:
  # the shelf was updated meanwhile).
  def fetch(title)
    return :too_big if title.size > @max_bytes

    data = @archive.file(title.path, max_bytes: @max_bytes)
    return :unavailable unless data
    return :changed unless data.bytesize == title.size && Zlib.crc32(data) == title.crc32

    data
  end

  # Counts a download that went through; a log that cannot be written does
  # not spoil it for the caller.
  def downloaded(title, protocol)
    @downloads.add(title.key, version: title.version, protocol: protocol)
  rescue SQLite3::Exception => e
    warn "warp-engine-bbs: the download of #{title.key} is not counted: #{e.class}: #{e.message}"
  end
end
