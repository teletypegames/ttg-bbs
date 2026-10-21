# frozen_string_literal: true

require 'net/ftp'
require_relative 'http_json'
require_relative '../model/ftp_models'

# Reads the public FTP server (anonymous, passive) the way a DOS client
# would: APPS has a folder per program with an INFO.INI, WARP the files of
# the game catalog. Listings and files are cached like the HTTP sources.
class FtpRepository
  include HttpJson

  def initialize(host)
    @host = host
  end

  def url(path = '') = "ftp://#{@host}#{path}"

  def apps
    cached(:apps) do
      connect do |ftp|
        entries(ftp, '/APPS').select(&:dir).map do |folder|
          info  = parse_ini(read(ftp, "/APPS/#{folder.name}/INFO.INI"))
          files = entries(ftp, "/APPS/#{folder.name}").reject(&:dir)
          FtpApp.new(folder: folder.name, title: info['name'] || folder.name, version: info['version'].to_s,
                     platform: info['platform'].to_s, description: info['description'].to_s, files: files)
        end
      end
    end
  rescue StandardError => e
    warn "FtpRepository apps error: #{e}"
    []
  end

  def warp
    cached(:warp) { connect { |ftp| entries(ftp, '/WARP') } }
  rescue StandardError => e
    warn "FtpRepository warp error: #{e}"
    []
  end

  def text(path)
    cached([:text, path]) do
      connect { |ftp| read(ftp, path) }.force_encoding(Encoding::UTF_8).scrub
    end
  rescue StandardError => e
    warn "FtpRepository text error (#{path}): #{e}"
    ''
  end

  private

  def connect(&block)
    Net::FTP.open(@host, passive: true, open_timeout: 10, read_timeout: 15) do |ftp|
      ftp.login
      block.call(ftp)
    end
  end

  def entries(ftp, path)
    ftp.mlsd(path).filter_map do |entry|
      type = entry.facts['type']
      next unless %w[dir file].include?(type)

      FtpEntry.new(name: entry.pathname, bytes: entry.facts['size'].to_i,
                   modified: entry.facts['modify'], dir: type == 'dir')
    end.sort_by(&:name)
  end

  def read(ftp, path)
    ftp.getbinaryfile(path, nil)
  rescue Net::FTPPermError
    +''
  end

  def parse_ini(text)
    text.to_s.each_line.with_object({}) do |line, acc|
      key, value = line.strip.split('=', 2)
      acc[key.downcase] = value.strip if value && !key.start_with?(';', '[')
    end
  end
end
