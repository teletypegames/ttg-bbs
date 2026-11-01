# frozen_string_literal: true

require 'zlib'

module Discovery
  # The files of a .zip archive in memory, from its central directory: the
  # stored and deflated members only (what the FTN info packs use). Enough to
  # take a nodelist out of an info pack without a gem or an unzip binary.
  module ZipReader
    EOCD    = "PK\x05\x06".b
    CENTRAL = "PK\x01\x02".b
    LOCAL   = "PK\x03\x04".b
    MAX_SIZE = 64 * 1024 * 1024

    module_function

    # The names of the members.
    def names(bytes) = entries(bytes).map(&:first)

    # The content of the first member whose name matches +pattern+, or nil.
    def read(bytes, pattern)
      name, method, csize, size, offset = entries(bytes).find { |e| File.basename(e[0]).match?(pattern) }
      return unless name
      raise ArgumentError, "zip member #{name} is too big" if size > MAX_SIZE
      raise ArgumentError, "zip member #{name}: no local header" unless bytes.byteslice(offset, 4) == LOCAL

      name_len, extra_len = bytes.byteslice(offset + 26, 4).unpack('vv')
      data = bytes.byteslice(offset + 30 + name_len + extra_len, csize)
      case method
      when 0 then data
      when 8 then Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data)
      else raise ArgumentError, "zip member #{name}: compression method #{method}"
      end
    end

    # [name, method, compressed size, size, local header offset] of each member.
    def entries(bytes)
      bytes = bytes.b
      eocd = bytes.rindex(EOCD)
      raise ArgumentError, 'not a zip archive' unless eocd

      count, _, dir_offset = bytes.byteslice(eocd + 10, 10).unpack('vVV')
      pos = dir_offset
      Array.new(count) do
        raise ArgumentError, 'broken zip directory' unless bytes.byteslice(pos, 4) == CENTRAL

        method, = bytes.byteslice(pos + 10, 2).unpack('v')
        csize, size, name_len, extra_len, comment_len = bytes.byteslice(pos + 20, 14).unpack('VVvvv')
        offset, = bytes.byteslice(pos + 42, 4).unpack('V')
        name = bytes.byteslice(pos + 46, name_len)
        pos += 46 + name_len + extra_len + comment_len
        [name, method, csize, size, offset]
      end
    end
  end
end
