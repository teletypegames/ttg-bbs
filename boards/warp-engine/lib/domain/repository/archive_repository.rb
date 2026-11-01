# frozen_string_literal: true

# The archive's plain HTTP (archive.teletypegames.org): the INDEX.TXT of a
# shelf, kept for +ttl+ seconds, and the bytes of a file. A dead archive
# gives the last index it sent, or nil.
class ArchiveRepository
  INDEX = 'INDEX.TXT'
  # An INDEX.TXT is a line a title; a shelf of thousands fits in this.
  INDEX_MAX_BYTES = 512 * 1024
  # The shelves are a handful; each one's titles are kept.
  SHELVES_KEPT = 32

  attr_reader :base_url

  def initialize(base_url, ttl:)
    @base_url = base_url.delete_suffix('/')
    @titles   = BBS::Cache.new(ttl: ttl, max_entries: SHELVES_KEPT)
  end

  def url(path) = "#{@base_url}#{path}"

  # The titles of +shelf+ in the order of its index, read again when
  # +fresh+; nil when the archive has never answered for it.
  def titles(shelf, fresh: false)
    fresh ? reread(shelf) : @titles.fetch(shelf.id) { index(shelf) }
  rescue BBS::HTTP::Error => e
    warn "warp-engine-bbs: #{e.message}"
    nil
  end

  # The bytes of +path+, at most +max_bytes+; nil when the archive does
  # not give them.
  def file(path, max_bytes:)
    get(path, max_bytes)
  rescue BBS::HTTP::Error => e
    warn "warp-engine-bbs: #{e.message}"
    nil
  end

  private

  # The index read now; when that fails, the one kept (an expired one too).
  def reread(shelf)
    titles = index(shelf)
    @titles.delete(shelf.id)
    @titles.fetch(shelf.id) { titles }
  rescue BBS::HTTP::Error => e
    @titles.fetch(shelf.id) { raise e }
  end

  def index(shelf)
    body = BBS::Text.clean(get("#{shelf.path}/#{INDEX}", INDEX_MAX_BYTES))
    body.each_line.filter_map { |line| TitleModel.parse(line, shelf) }.freeze
  end

  def get(path, max_bytes)
    response = BBS::HTTP.get(url(path), max_bytes: max_bytes)
    raise BBS::HTTP::Error, "GET #{url(path)}: answered #{response.status}" unless response.ok?

    response.body
  end
end
