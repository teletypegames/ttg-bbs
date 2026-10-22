# frozen_string_literal: true

require 'net/ftp'
require 'time'
require_relative 'http_json'
require_relative '../model/ftp_models'

# Reads the public FTP server (anonymous, passive) like any FTP client: the
# listing of a folder, and the bytes of a file. Listings are cached for a
# minute, so moving around the folders does not log in on every keypress.
class FtpRepository
  include HttpJson

  LISTING_TTL = 60

  def initialize(host)
    @host = host
  end

  attr_reader :host

  def url(path = '/') = "ftp://#{@host}#{path}"

  # The entries of a folder, folders first; nil when the server did not answer.
  def list(path)
    cached([:list, path], ttl: LISTING_TTL) { connect { |ftp| entries(ftp, path) } }
  rescue StandardError => e
    warn "FtpRepository list error (#{path}): #{e}"
    nil
  end

  # The bytes of a file; nil when it could not be read.
  def read(path)
    connect { |ftp| ftp.getbinaryfile(path, nil) }
  rescue StandardError => e
    warn "FtpRepository read error (#{path}): #{e}"
    nil
  end

  def text(path)
    cached([:text, path]) { read(path).to_s.force_encoding(Encoding::UTF_8).scrub }
  end

  private

  def connect(&block)
    Net::FTP.open(@host, passive: true, open_timeout: 10, read_timeout: 15) do |ftp|
      ftp.login
      block.call(ftp)
    end
  end

  def entries(ftp, path)
    list = ftp.mlsd(path).filter_map do |entry|
      type = entry.facts['type']
      next unless %w[dir file].include?(type)

      FtpEntry.new(name: entry.pathname, path: File.join(path, entry.pathname), bytes: entry.facts['size'].to_i,
                   modified: modified(entry.facts['modify']), dir: type == 'dir')
    end
    list.sort_by { |e| [e.dir ? 0 : 1, e.name.downcase] }
  end

  def modified(fact)
    fact.is_a?(Time) ? fact : Time.strptime("#{fact.to_s[0, 14]} UTC", '%Y%m%d%H%M%S %Z')
  rescue ArgumentError
    nil
  end
end
