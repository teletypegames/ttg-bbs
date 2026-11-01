# frozen_string_literal: true

require 'net/http'
require 'uri'

module Discovery
  # Downloads a source list over HTTP(S), following up to five redirects, at
  # most MAX_BYTES; from a .zip the member of the source's +member+ pattern.
  # Raises FetchError on any failure.
  class SourceFetcher
    class FetchError < StandardError; end

    MAX_BYTES  = 32 * 1024 * 1024
    TIMEOUT    = 30
    USER_AGENT = 'TTG-Gate-BBS-Discovery/1.0 (+https://wiki.teletypegames.org/services/ttg-gate-bbs)'

    # The bytes of +source+ (a SourceModel).
    def fetch(source)
      bytes = get(URI(source.url))
      return bytes unless source.member

      ZipReader.read(bytes, source.member) or raise FetchError, "#{source.id}: no member like #{source.member.source}"
    rescue ArgumentError => e
      raise FetchError, "#{source.id}: #{e.message}"
    end

    # The body of +uri+ (binary).
    def get(uri, redirects = 5)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri, 'User-Agent' => USER_AGENT)
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess then return body(response, uri)
          when Net::HTTPRedirection
            raise FetchError, "#{uri}: too many redirects" if redirects.zero?

            return get(uri + response['location'], redirects - 1)
          else raise FetchError, "#{uri}: HTTP #{response.code}"
          end
        end
      end
    rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError => e
      raise FetchError, "#{uri}: #{e.class}: #{e.message}"
    end

    private

    def body(response, uri)
      bytes = +''.b
      response.read_body do |chunk|
        bytes << chunk
        raise FetchError, "#{uri}: more than #{MAX_BYTES} bytes" if bytes.bytesize > MAX_BYTES
      end
      bytes
    end
  end
end
