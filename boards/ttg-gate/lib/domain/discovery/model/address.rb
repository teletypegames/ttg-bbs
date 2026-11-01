# frozen_string_literal: true

require 'ipaddr'

module Discovery
  # The rules of a catalog key: a host is lowercase without the closing dot, a
  # port 1-65535.
  #
  # The catalog comes from third-party lists, and the Gate calls what it
  # lists and relays a caller's line to it, so a board is called only on the
  # public internet (callable?): every address its name resolves to is
  # public, and the port is no well-known port of another service.
  module Address
    HOSTNAME = /\A(?=.{1,253}\z)(?:[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
    SERVICE_PORTS = [22, 25, 53, 110, 111, 135, 139, 143, 445, 465, 587, 993, 995, 2375, 2376, 3306, 5432,
                     6379, 9200, 11_211, 27_017].freeze

    module_function

    # +host+ normalized, or nil when it is not a host name or an IP address.
    def host(text)
      host = text.to_s.strip.downcase.delete_prefix('[').delete_suffix(']').chomp('.')
      return if host.empty?
      return host if ip?(host)
      return unless host.match?(HOSTNAME) && host.include?('.')
      return if host.match?(/\A[\d.]+\z/)

      host
    end

    # +text+ as a port, or nil.
    def port(text)
      port = Integer(text.to_s.strip, 10)
      port.between?(1, 65_535) ? port : nil
    rescue ArgumentError, TypeError
      nil
    end

    # Whether +ip+ is an address on the public internet: BBS::Address.public?,
    # whose ranges hold every one this board blocked before, and the
    # documentation ranges besides.
    def public?(ip) = BBS::Address.public?(ip)

    # Whether the Gate may call +ips+ (what a name resolved to) on +port+:
    # there is an address, every one is public, and the port is one.
    def callable?(ips, port)
      !ips.empty? && ips.all? { |ip| public?(ip) } && !SERVICE_PORTS.include?(port)
    end

    def ip?(text)
      IPAddr.new(text.to_s)
      true
    rescue IPAddr::Error
      false
    end

    # A field of a source: no control or bidi characters (BBS::Text.clean),
    # whitespace runs one space, trimmed, Unicode NFC; nil when empty. A
    # third-party list must not move the cursor or recolour a caller's screen.
    def text(value)
      text = BBS::Text.clean(value).unicode_normalize(:nfc).gsub(/[[:space:]]+/, ' ').strip
      text.empty? ? nil : text
    end
  end
end
