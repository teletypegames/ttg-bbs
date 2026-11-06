# frozen_string_literal: true

# The ANSI gallery: the years, packs and text-art files of 16colo.rs, and a
# piece rendered into an ArtModel. A file is fetched only when it is shown,
# and kept in the disk cache. When the archive does not answer, that is
# logged once here and the faces get nil (or :unavailable).
class GalleryService
  def initialize(remote:, cache:, renderer:)
    @remote   = remote
    @cache    = cache
    @renderer = renderer
  end

  # The years with packs, newest first; nil when the archive does not answer.
  def years = answer('years') { @remote.years }

  # The packs of +year+ (a YearModel or an Integer); nil when the archive
  # does not answer.
  def packs(year)
    year = year.year if year.respond_to?(:year)
    answer("packs of #{year}") { @remote.packs(year) }
  end

  # The text-art files of +pack+, by name; nil when the archive does not
  # answer.
  def files(pack)
    answer("files of #{pack.name}") { @remote.files(pack.name) }&.select(&:text_art?)&.sort_by { |f| f.name.downcase }
  end

  # +file+ rendered, an ArtModel; :unavailable when it cannot be fetched,
  # :too_big when it is larger than the board takes.
  def piece(file)
    key  = "#{file.pack}/#{file.name}"
    data = @cache.read(key) || fetch(key, file)
    data.is_a?(Symbol) ? data : @renderer.render(data)
  end

  def site_url = @remote.site_url

  def pack_url(pack) = @remote.pack_url(pack.name)

  def file_url(file) = @remote.file_url(file.pack, file.name)

  private

  # The bytes of +file+ from the archive, kept in the disk cache under
  # +key+; :too_big or :unavailable.
  def fetch(key, file)
    @remote.raw(file.pack, file.name).tap { |data| @cache.write(key, data) }
  rescue Rubbs::Common::Web::HTTP::TooLarge
    :too_big
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('16colors', "#{key}: #{e.message}")
    :unavailable
  end

  # The block's value, or nil (logged) when the archive did not answer.
  def answer(what)
    yield
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('16colors', "#{what}: #{e.class}: #{e.message}")
    nil
  end
end
