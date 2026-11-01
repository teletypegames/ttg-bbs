# frozen_string_literal: true

require 'digest'

module Discovery
  # What the bytes of a banner say, by fixed rules (TTG_DISCOVERY.md §6.1).
  module BannerAnalyzer
    ESC = 0x1B
    # PETSCII: CLR, the charset switches, RVS on/off.
    PETSCII_STRONG = [0x93, 0x0E, 0x8E].freeze
    # PETSCII colours: white, red, green, blue, orange, black, brown, light
    # red, dark grey, grey, light green, light blue, purple, yellow, cyan.
    # Light grey (0x9B) is left out: it is the ATASCII end of line, and a
    # PETSCII banner has other codes besides.
    PETSCII_COLOURS = [0x05, 0x1C, 0x1E, 0x1F, 0x81, 0x90, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9C, 0x9E, 0x9F].freeze
    ATASCII_EOL = 0x9B
    ATASCII_CLR = 0x7D

    module_function

    # The encoding of +banner+ (binary): ansi, petscii, atascii, ascii, or
    # unknown (also for an empty banner). The first rule that holds wins:
    #
    # 1. ESC [ in it: ansi.
    # 2. No ESC, and a PETSCII control code: CLR (0x93), a charset switch
    #    (0x0E/0x8E), or a colour code in bytes that are not UTF-8 text:
    #    petscii.
    # 3. The ATASCII end of line (0x9B), or its clear screen (0x7D) as the
    #    first byte: atascii. (Anywhere else 0x7D is an ASCII brace.)
    # 4. Only 0x20-0x7E, CR, LF (and TAB, BS, BEL, NUL): ascii.
    # 5. Anything else: unknown.
    def encoding(banner)
      bytes = banner.to_s.b
      return 'unknown' if bytes.empty?
      return 'ansi' if bytes.include?("\e[")

      codes = bytes.bytes
      return 'petscii' if !codes.include?(ESC) && petscii?(bytes, codes)
      return 'atascii' if codes.include?(ATASCII_EOL) || codes.first == ATASCII_CLR
      return 'ascii' if codes.all? { |c| c.between?(0x20, 0x7E) || [0x0D, 0x0A, 0x09, 0x08, 0x07, 0x00].include?(c) }

      'unknown'
    end

    def petscii?(bytes, codes)
      return true if codes.intersect?(PETSCII_STRONG)
      return false unless codes.intersect?(PETSCII_COLOURS)

      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      !(utf8.valid_encoding? && !utf8.ascii_only?)
    end

    # +banner+ as plain ASCII text to match signatures on: escape sequences
    # out, in a PETSCII banner the capitals (0xC1-0xDA) folded to A-Z, every
    # other byte outside 0x20-0x7E a space.
    def text(banner, petscii: encoding(banner) == 'petscii')
      bytes = banner.to_s.b.gsub(%r{\e\[[0-9;?]*[ -/]*[@-~]}n, ' ').gsub(/\e./n, ' ')
      bytes.bytes.map do |c|
        if c.between?(0x20, 0x7E) then c
        elsif petscii && c.between?(0xC1, 0xDA) then c - 0x80
        else 0x20
        end
      end.pack('C*').squeeze(' ')
    end

    # The signature (ConfigRepository::Signature) of the first of
    # +signatures+ that matches +text+, or nil.
    def software(text, signatures) = signatures.find { |s| text.to_s.match?(s.pattern) }

    # The banner's hash: the first 16 hex digits of its SHA-256, nil when
    # empty.
    def digest(banner) = banner.to_s.empty? ? nil : Digest::SHA256.hexdigest(banner.to_s.b)[0, 16]
  end
end
