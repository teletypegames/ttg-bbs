# frozen_string_literal: true

# The ANSI gallery: the years, packs and text-art files of 16colo.rs, and a
# piece rendered into an ArtModel. A file is fetched only when it is shown,
# and kept in the disk cache.
class GalleryService
  def initialize(remote:, cache:, renderer:)
    @remote   = remote
    @cache    = cache
    @renderer = renderer
  end

  # The years with packs, newest first; nil when the archive does not answer.
  def years = @remote.years

  # The packs of +year+ (a YearModel or an Integer); nil when the archive
  # does not answer.
  def packs(year) = @remote.packs(year.respond_to?(:year) ? year.year : year)

  # The text-art files of +pack+, by name; nil when the archive does not
  # answer.
  def files(pack)
    @remote.files(pack.name)&.select(&:text_art?)&.sort_by { |f| f.name.downcase }
  end

  # +file+ rendered, an ArtModel; :unavailable when it cannot be fetched,
  # :too_big when it is larger than the board takes.
  def piece(file)
    key  = "#{file.pack}/#{file.name}"
    data = @cache.read(key)
    unless data
      data = @remote.raw(file.pack, file.name)
      return :too_big if data == :too_big
      return :unavailable unless data

      @cache.write(key, data)
    end
    @renderer.render(data)
  end

  def site_url = @remote.site_url

  def pack_url(pack) = @remote.pack_url(pack.name)

  def file_url(file) = @remote.file_url(file.pack, file.name)
end
