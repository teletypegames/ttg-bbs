# frozen_string_literal: true

require 'fileutils'

# Project Gutenberg over HTTP (BBS::HTTP: a deadline, a cap on the body,
# redirects to public http(s) addresses only, the board's User-Agent): the
# catalog file and the plain text of a book, from the mirror the board is
# given. A dead mirror gives nil.
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
  # [user_agent]  the User-Agent sent with every request
  def initialize(mirror:, catalog_url:, user_agent:)
    @mirror      = mirror.delete_suffix('/')
    @catalog_url = catalog_url
    @user_agent  = user_agent
  end

  def text_url(id) = "#{@mirror}/cache/epub/#{Integer(id)}/pg#{Integer(id)}.txt"

  # Saves the catalog file at +path+ (through a temporary file next to it).
  # Returns true, or false when the mirror did not give it.
  def download_catalog(path)
    body = get(@catalog_url, max_bytes: CATALOG_MAX, deadline: CATALOG_DEADLINE)
    return false unless body.is_a?(String)

    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite("#{path}.part", body)
    File.rename("#{path}.part", path)
    true
  rescue SystemCallError => e
    warn "scriptorium-bbs: #{path}: #{e.class}: #{e.message}"
    false
  end

  # The bytes of book +id+'s plain text; :too_big when it is longer than
  # +max_bytes+; nil when the mirror does not give it.
  def text(id, max_bytes:) = get(text_url(id), max_bytes: max_bytes, deadline: TEXT_DEADLINE)

  private

  # The body of a successful GET of +url+; :too_big for a body over
  # +max_bytes+; nil when the mirror fails.
  def get(url, max_bytes:, deadline:)
    response = BBS::HTTP.get(url, max_bytes: max_bytes, deadline: deadline, read_timeout: READ_TIMEOUT,
                                  user_agent: @user_agent)
    return response.body if response.ok?

    warn "scriptorium-bbs: #{url} answered #{response.status}"
    nil
  rescue BBS::HTTP::Error => e
    warn "scriptorium-bbs: #{e.message}"
    e.message.end_with?("over #{max_bytes} bytes") ? :too_big : nil
  end
end
