# frozen_string_literal: true

require 'net/http'
require 'uri'

# The archive's plain HTTP (archive.teletypegames.org): the INDEX.TXT of a
# shelf, kept for +ttl+ seconds, and the bytes of a file. A dead archive
# gives the last index it sent, or nil.
class ArchiveRepository
  INDEX = 'INDEX.TXT'
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  attr_reader :base_url

  def initialize(base_url, ttl:)
    @base_url = base_url.delete_suffix('/')
    @ttl      = ttl
    @indexes  = {}
    @lock     = Mutex.new
  end

  def url(path) = "#{@base_url}#{path}"

  # The titles of +shelf+ in the order of its index; nil when the archive
  # has never answered for it.
  def titles(shelf, fresh: false)
    cached = @lock.synchronize { @indexes[shelf.id] }
    return cached[:titles] if cached && !fresh && now - cached[:at] < @ttl

    body = get("#{shelf.path}/#{INDEX}")
    return cached&.dig(:titles) unless body

    titles = body.force_encoding(Encoding::UTF_8).scrub.each_line.filter_map { |line| TitleModel.parse(line, shelf) }.freeze
    @lock.synchronize { @indexes[shelf.id] = { titles: titles, at: now } }
    titles
  end

  # The bytes of +path+, nil when the archive does not give them.
  def file(path) = get(path)

  private

  def get(path)
    uri = URI(url(path))
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                              open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
    return res.body.b if res.is_a?(Net::HTTPSuccess)

    warn "warp-engine-bbs: #{uri} answered #{res.code}"
    nil
  rescue StandardError => e
    warn "warp-engine-bbs: #{uri}: #{e.class}: #{e.message}"
    nil
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
