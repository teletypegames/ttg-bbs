# frozen_string_literal: true

require 'fileutils'

# Project Gutenberg over HTTP (BBS::HTTP: a deadline, a cap on the body,
# redirects to public http(s) addresses only, the board's User-Agent): the
# catalog file and the plain text of a book, from the mirror the board is
# given. A dead mirror raises BBS::HTTP::Error, a body over the cap its
# subclass BBS::HTTP::TooLarge.
class GutenbergRepository
  # The catalog file is about 6 MB.
  CATALOG_MAX = 32 * 1024 * 1024
  CATALOG_DEADLINE = 300
  # Seconds a book's text may take, redirects included.
  TEXT_DEADLINE = 60
  READ_TIMEOUT  = 30

  attr_reader :mirror

  # [mirror]      the base URL of the mirror (https://www.gutenberg.org)
  # [catalog_url] the URL of pg_catalog.csv.gz
  def initialize(mirror:, catalog_url:)
    @mirror      = mirror.delete_suffix('/')
    @catalog_url = catalog_url
  end

  def text_url(id) = "#{@mirror}/cache/epub/#{Integer(id)}/pg#{Integer(id)}.txt"

  # Saves the catalog file at +path+, streamed into a temporary file next
  # to it, so the download never sits in memory. Raises BBS::HTTP::Error or
  # SystemCallError; +path+ is then left as it was.
  def download_catalog(path)
    FileUtils.mkdir_p(File.dirname(path))
    File.open("#{path}.part", 'wb') do |file|
      get(@catalog_url, to: file, max_bytes: CATALOG_MAX, deadline: CATALOG_DEADLINE)
    end
    File.rename("#{path}.part", path)
  ensure
    FileUtils.rm_f("#{path}.part")
  end

  # The bytes of book +id+'s plain text. Raises BBS::HTTP::TooLarge when it
  # is longer than +max_bytes+.
  def text(id, max_bytes:) = get(text_url(id), max_bytes: max_bytes, deadline: TEXT_DEADLINE).body

  private

  # The Response of a successful GET of +url+; an error status raises
  # BBS::HTTP::Error.
  def get(url, **)
    response = BBS::HTTP.get(url, read_timeout: READ_TIMEOUT, **)
    raise BBS::HTTP::Error, "GET #{url}: answered #{response.status}" unless response.ok?

    response
  end
end
