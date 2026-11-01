# frozen_string_literal: true

require 'zlib'

module Discovery
  # The files of a .zip archive in memory, from its central directory: the
  # stored and deflated members only (what the FTN info packs use). Enough to
  # take a nodelist out of an info pack without a gem or an unzip binary.
  #
  # A member is inflated CHUNK bytes at a time and stops at MAX_SIZE bytes
  # out, whatever its header claims, so a zip bomb in a source list cannot
  # fill the prober's memory.
  module ZipReader
    EOCD     = "PK\x05\x06".b
    CENTRAL  = "PK\x01\x02".b
    LOCAL    = "PK\x03\x04".b
    MAX_SIZE = 16 * 1024 * 1024
    CHUNK    = 64 * 1024

    # A member of the central directory.
    Entry = Data.define(:name, :compression, :csize, :size, :offset)

    module_function

    # The names of the members.
    def names(bytes) = entries(bytes).map(&:name)

    # The content of the first member whose name matches +pattern+, or nil.
    # Raises ArgumentError for a broken archive or a member over +max+ bytes.
    def read(bytes, pattern, max: MAX_SIZE)
      bytes = bytes.b
      entry = entries(bytes).find { |e| File.basename(e.name).match?(pattern) }
      return unless entry
      raise ArgumentError, "zip member #{entry.name} is too big" if entry.size > max

      data = bytes.byteslice(data_offset(bytes, entry), entry.csize).to_s
      case entry.compression
      when 0 then capped(data, entry.name, max)
      when 8 then inflate(data, entry.name, max)
      else raise ArgumentError, "zip member #{entry.name}: compression method #{entry.compression}"
      end
    end

    # The Entry of each member.
    def entries(bytes)
      bytes = bytes.b
      eocd = bytes.rindex(EOCD)
      raise ArgumentError, 'not a zip archive' unless eocd && bytes.bytesize >= eocd + 22

      count, _, pos = bytes.byteslice(eocd + 10, 10).unpack('vVV')
      Array.new(count) do
        entry, pos = entry_at(bytes, pos)
        entry
      end
    end

    # The Entry at +pos+ of the central directory, and where the next one is.
    def entry_at(bytes, pos)
      raise ArgumentError, 'broken zip directory' unless bytes.byteslice(pos, 46)&.bytesize == 46 &&
                                                         bytes.byteslice(pos, 4) == CENTRAL

      method, = bytes.byteslice(pos + 10, 2).unpack('v')
      csize, size, name_len, extra_len, comment_len = bytes.byteslice(pos + 20, 14).unpack('VVvvv')
      offset, = bytes.byteslice(pos + 42, 4).unpack('V')
      name = bytes.byteslice(pos + 46, name_len).to_s
      [Entry.new(name: name, compression: method, csize: csize, size: size, offset: offset),
       pos + 46 + name_len + extra_len + comment_len]
    end

    # Where the data of +entry+ starts, after its local header.
    def data_offset(bytes, entry)
      offset = entry.offset
      raise ArgumentError, "zip member #{entry.name}: no local header" unless bytes.byteslice(offset, 4) == LOCAL

      name_len, extra_len = bytes.byteslice(offset + 26, 4).unpack('vv')
      offset + 30 + name_len + extra_len
    end

    # +data+ inflated (raw deflate), CHUNK bytes in at a time, at most +max+
    # bytes out.
    def inflate(data, name, max)
      inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      out = +''.b
      (0...data.bytesize).step(CHUNK) do |at|
        inflater.inflate(data.byteslice(at, CHUNK)) { |part| out << capped(part, name, max - out.bytesize) }
      end
      out << capped(inflater.finish, name, max - out.bytesize)
    rescue Zlib::Error => e
      raise ArgumentError, "zip member #{name}: #{e.message}"
    ensure
      inflater&.close
    end

    # +data+, unless it is over +max+ bytes.
    def capped(data, name, max)
      raise ArgumentError, "zip member #{name} is too big" if data.bytesize > max

      data
    end
  end
end
