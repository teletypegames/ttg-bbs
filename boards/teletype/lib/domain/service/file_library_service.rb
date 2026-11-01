# frozen_string_literal: true

# The FTP server as the BBS's file area: browse any folder from the root,
# read the text files in place, and send a file to the caller by ZMODEM.
# WARP files are on teletypegames.org over HTTPS as well, and every file
# on the archive's plain HTTP.
class FileLibraryService
  ROOT         = '/'
  TEXT_FILES   = /\.(md|txt|ini|lst|bat|cfg|nfo|diz|asc|json|html?)\z/i
  PREVIEW_MAX  = 64 * 1024
  DOWNLOAD_MAX = Integer(ENV.fetch('TELETYPE_BBS_FTP_DOWNLOAD_MAX', 16 * 1024 * 1024))
  WARP_HTTP    = 'https://teletypegames.org/file'
  ARCHIVE_HTTP = ENV.fetch('TELETYPE_BBS_ARCHIVE_URL', 'http://archive.teletypegames.org')

  def initialize(repo)
    @repo = repo
  end

  def host = @repo.host
  def list(path) = @repo.list(path)
  def url(path) = @repo.url(path)
  def parent(path) = File.dirname(path)

  def https_url(path)
    rest = path.delete_prefix('/WARP/')
    "#{WARP_HTTP}/#{rest}" unless rest == path
  end

  # The whole FTP tree is on plain HTTP too, for machines without TLS.
  def http_url(path) = "#{ARCHIVE_HTTP}#{path}"

  def preview?(entry) = !entry.dir && entry.bytes <= PREVIEW_MAX && entry.name.match?(TEXT_FILES)
  def preview(entry) = preview?(entry) ? @repo.text(entry.path) : ''

  def downloadable?(entry) = !entry.dir && entry.bytes <= DOWNLOAD_MAX
  def download(entry) = downloadable?(entry) ? @repo.read(entry.path) : nil

  # The size in bytes of a file at the top of WARP, nil when it is not there.
  def warp_size(name) = @repo.list('/WARP')&.find { |f| f.name == name }&.bytes
end
