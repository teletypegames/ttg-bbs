# frozen_string_literal: true

require 'zlib'

# The board's file area: the directories, their titles, and a title's bytes for
# a download, but only when they are the ones its index line promises.
class CatalogService
  def initialize(directories:, archive:, max_bytes:)
    @directories = directories
    @archive   = archive
    @max_bytes = max_bytes
  end

  def directories = @directories.all

  # The titles of +directory+; nil when the archive does not answer.
  def titles(directory, fresh: false)
    @archive.titles(directory, fresh: fresh)
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('archive', e.message)
    nil
  end

  # The archive's address of a directory or a title.
  def url(item) = @archive.url(item.path)

  def downloads(title) = DownloadModel.of(title.key)

  # The bytes of +title+, or why not: :too_big, :unavailable (the archive
  # did not give them), :changed (not the size or CRC-32 of the index line:
  # the directory was updated meanwhile).
  def fetch(title)
    return :too_big if title.size > @max_bytes

    data = file(title)
    return :unavailable unless data
    return :changed unless data.bytesize == title.size && Zlib.crc32(data) == title.crc32

    data
  end

  # Counts a download that went through; a log that cannot be written does
  # not spoil it for the caller.
  def downloaded(title, protocol)
    Rubbs.achieve(:download, ref: title.key.to_s, protocol: protocol.to_s)
    DownloadModel.add(title.key, version: title.version, protocol: protocol)
  rescue Sequel::DatabaseError => e
    Rubbs.log('downloads', "the download of #{title.key} is not counted: #{e.class}: #{e.message}")
  end

  private

  # The bytes of +title+ from the archive; nil when they do not come.
  def file(title)
    @archive.file(title.path, max_bytes: @max_bytes)
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('archive', e.message)
    nil
  end
end
