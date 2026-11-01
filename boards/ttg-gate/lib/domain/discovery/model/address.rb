# frozen_string_literal: true

require 'ipaddr'

module Discovery
  # The rules of a catalog key: a host is lowercase without the closing dot, a
  # port 1-65535.
  module Address
    HOSTNAME = /\A(?=.{1,253}\z)(?:[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

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
