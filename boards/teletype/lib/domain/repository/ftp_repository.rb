# frozen_string_literal: true

require 'net/ftp'
require_relative 'http_json'

# Reads the public FTP server (anonymous, passive) for one thing: the size
# of each file in a folder. A listing is cached for ten minutes, so a disk
# directory on the Commodore doors does not log in on every LOAD"$",8.
class FtpRepository
  LISTING_TTL = 600

  def initialize(host)
    @host  = host
    @cache = HttpJson::Cache.new(ttl: LISTING_TTL, max_entries: 64)
  end

  # {name => bytes} of the files of +path+. Raises Net::FTPError or
  # SystemCallError when the server did not answer.
  def sizes(path)
    @cache.fetch([:sizes, path]) do
      Net::FTP.open(@host, passive: true, open_timeout: 10, read_timeout: 15) do |ftp|
        ftp.login
        ftp.mlsd(path).select { |e| e.facts['type'] == 'file' }.to_h { |e| [BBS::Text.clean(e.pathname), e.facts['size'].to_i] }
      end
    end
  end
end
