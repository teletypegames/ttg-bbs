# frozen_string_literal: true

# The archive's plain HTTP (archive.teletypegames.org): the INDEX.TXT of a
# directory, kept for +ttl+ seconds, and the bytes of a file. A dead archive
# gives the last index it sent; when there is none, or a file does not
# come, it raises Rubbs::Common::Web::HTTP::Error.
class ArchiveRepository
  INDEX = 'INDEX.TXT'
  # An INDEX.TXT is a line a title; a directory of thousands fits in this.
  INDEX_MAX_BYTES = 512 * 1024
  # The directories are a handful; each one's titles are kept.
  DIRECTORIES_KEPT = 32

  attr_reader :base_url

  def initialize(base_url, ttl:)
    @base_url = base_url.delete_suffix('/')
    @titles   = Rubbs::Common::Storage::Cache.new(ttl: ttl, max_entries: DIRECTORIES_KEPT)
  end

  def url(path) = "#{@base_url}#{path}"

  # The titles of +directory+ in the order of its index, read again when
  # +fresh+.
  def titles(directory, fresh: false)
    fresh ? reread(directory) : @titles.fetch(directory.id) { index(directory) }
  end

  # The bytes of +path+, at most +max_bytes+.
  def file(path, max_bytes:) = get(path, max_bytes)

  private

  # The index read now; when that fails, the one kept (an expired one too).
  def reread(directory)
    @titles.refresh(directory.id) { index(directory) }
  rescue Rubbs::Common::Web::HTTP::Error => e
    @titles.fetch(directory.id) { raise e }
  end

  def index(directory)
    body = Rubbs::Common::Text.clean(get("#{directory.path}/#{INDEX}", INDEX_MAX_BYTES))
    body.each_line.filter_map { |line| TitleModel.parse(line, directory) }.freeze
  end

  def get(path, max_bytes)
    response = Rubbs::Common::Web::HTTP.get(url(path), max_bytes: max_bytes)
    raise Rubbs::Common::Web::HTTP::Error, "GET #{url(path)}: answered #{response.status}" unless response.ok?

    response.body
  end
end
