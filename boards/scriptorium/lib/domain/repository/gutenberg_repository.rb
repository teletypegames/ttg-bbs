# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'fileutils'

# Project Gutenberg over HTTP: the catalog file and the plain text of a
# book, from the mirror the board is given. Every request names the board
# in its User-Agent. A dead mirror gives nil.
class GutenbergRepository
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 60
  REDIRECTS    = 3

  # Raised inside a download to stop it: the text is longer than allowed.
  # Net::HTTP would otherwise read the rest of the body when the block ends.
  class TooBig < StandardError; end

  attr_reader :mirror

  # [mirror]      the base URL of the mirror (https://www.gutenberg.org)
  # [catalog_url] the URL of pg_catalog.csv.gz
  # [user_agent]  the User-Agent sent with every request
  def initialize(mirror:, catalog_url:, user_agent:)
    @mirror      = mirror.delete_suffix('/')
    @catalog_url = catalog_url
    @user_agent  = user_agent
  end

  def text_url(id) = "#{@mirror}/cache/epub/#{id}/pg#{id}.txt"

  # Saves the catalog file at +path+ (through a temporary file next to it).
  # Returns true, or false when the mirror did not give it.
  def download_catalog(path)
    tmp = "#{path}.part"
    FileUtils.mkdir_p(File.dirname(path))
    ok = File.open(tmp, 'wb') do |file|
      get(@catalog_url) { |res| res.read_body { |chunk| file.write(chunk) } }
    end
    ok ? File.rename(tmp, path) : FileUtils.rm_f(tmp)
    ok ? true : false
  rescue SystemCallError => e
    warn "scriptorium-bbs: #{path}: #{e.class}: #{e.message}"
    FileUtils.rm_f(tmp)
    false
  end

  # The bytes of book +id+'s plain text; :too_big when it is longer than
  # +max_bytes+; nil when the mirror does not give it.
  def text(id, max_bytes:)
    body = +''
    ok = get(text_url(id)) do |res|
      raise TooBig if res['content-length'].to_i > max_bytes

      res.read_body do |chunk|
        body << chunk
        raise TooBig if body.bytesize > max_bytes
      end
    end
    ok ? body.b : nil
  rescue TooBig
    :too_big
  end

  private

  # Yields the successful response of a GET of +url+, following redirects;
  # true when there was one.
  def get(url, redirects = REDIRECTS, &block)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(Net::HTTP::Get.new(uri, 'User-Agent' => @user_agent)) do |res|
        case res
        when Net::HTTPSuccess
          block.call(res)
          return true
        when Net::HTTPRedirection
          return get(URI.join(url, res['location']).to_s, redirects - 1, &block) if redirects.positive?
        end
        warn "scriptorium-bbs: #{url} answered #{res.code}"
        return false
      end
    end
  rescue TooBig
    raise
  rescue StandardError => e
    warn "scriptorium-bbs: #{url}: #{e.class}: #{e.message}"
    false
  end
end
