# frozen_string_literal: true

require 'cgi'
require 'tempfile'
require 'uri'

module Discovery
  # Downloads a source list over HTTP(S) through BBS::HTTP: at most
  # MAX_BYTES within DEADLINE seconds, following up to five redirects to
  # http or https hosts on the public internet only (a list cannot point the
  # importer at the Docker network); from a .zip the member of the source's
  # +member+ pattern. A source with a +link+ pattern is a page that links its
  # list under a name that changes (a monthly file): the first link of the
  # page that matches is downloaded. Raises FetchError on any failure.
  class SourceFetcher
    class FetchError < StandardError; end

    MAX_BYTES  = 32 * 1024 * 1024
    TIMEOUT    = 30
    DEADLINE   = 300
    REDIRECTS  = 5
    USER_AGENT = 'TTG-Gate-BBS-Discovery/1.0 (+https://wiki.teletypegames.org/services/ttg-gate-bbs)'

    # The bytes of +source+ (a SourceConfigModel). From a .zip only its member is
    # read into the memory, not the archive.
    def fetch(source)
      download(source.link ? linked(source) : URI(source.url)) do |file|
        next file.read unless source.member

        ZipReader.read(file, source.member) or raise FetchError, "#{source.id}: no member like #{source.member.source}"
      end
    rescue ArgumentError => e
      raise FetchError, "#{source.id}: #{e.message}"
    end

    # The body of +uri+ (binary).
    def get(uri) = download(uri, &:read)

    # Downloads +uri+ into a temporary file, yields it (binary, at its start)
    # and returns what the block returns; the file is gone afterwards. So a
    # list of up to MAX_BYTES never sits in the memory whole as it comes in.
    def download(uri)
      Tempfile.create('ttg-gate-bbs-source', binmode: true) do |file|
        response = BBS::HTTP.get(uri.to_s, open_timeout: TIMEOUT, read_timeout: TIMEOUT, deadline: DEADLINE, to: file,
                                           max_bytes: MAX_BYTES, redirects: REDIRECTS, user_agent: USER_AGENT)
        raise FetchError, "#{uri}: HTTP #{response.status}" unless response.ok?

        file.rewind
        yield file
      end
    rescue BBS::HTTP::Error => e
      raise FetchError, e.message
    end

    # The URI of the first link of the source's page that matches its +link+.
    def linked(source)
      page = get(URI(source.url)).force_encoding(Encoding::UTF_8).scrub('?')
      href = page.scan(/href\s*=\s*["']([^"']+)["']/i).flatten.find { |h| h.match?(source.link) }
      raise FetchError, "#{source.id}: no link like #{source.link.source} on #{source.url}" unless href

      URI(source.url) + CGI.unescapeHTML(href)
    end
  end
end
