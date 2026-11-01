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
    NON_PUBLIC = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24
      192.168.0.0/16 198.18.0.0/15 224.0.0.0/3 ::/127 64:ff9b::/96 100::/64 fc00::/7 fe80::/10 ff00::/8
    ].map { |range| IPAddr.new(range) }.freeze
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

    # Whether +ip+ is an address on the public internet.
    def public?(ip)
      addr = IPAddr.new(ip.to_s)
      addr = addr.native if addr.ipv4_mapped?
      NON_PUBLIC.none? { |range| range.family == addr.family && range.include?(addr) }
    rescue IPAddr::Error
      false
    end

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

    # A field of a source: whitespace runs one space, trimmed, Unicode NFC; nil
    # when empty.
    def text(value)
      text = value.to_s.dup.force_encoding(Encoding::UTF_8)
      text = text.scrub('?') unless text.valid_encoding?
      text = text.unicode_normalize(:nfc).gsub(/[[:space:]]+/, ' ').strip
      text.empty? ? nil : text
    end
  end
end
