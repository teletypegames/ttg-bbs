# frozen_string_literal: true

require 'stringio'
require 'zlib'

module Discovery
  # The files of a .zip archive, from its central directory: the stored and
  # deflated members only (what the FTN info packs use). Enough to take a
  # nodelist out of an info pack without a gem or an unzip binary. The
  # archive is a String or a file (an IO that seeks): only its directory and
  # the member asked for are read.
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
    # The end of an archive its end-of-directory record sits in: the record
    # and a comment of at most 65535 bytes.
    TAIL = 22 + 0xFFFF

    # A member of the central directory.
    Entry = Data.define(:name, :compression, :csize, :size, :offset)

    module_function

    # The names of the members of +zip+.
    def names(zip) = entries(io(zip)).map(&:name)

    # The content of the first member of +zip+ whose name matches +pattern+,
    # or nil. Raises ArgumentError for a broken archive or a member over
    # +max+ bytes.
    def read(zip, pattern, max: MAX_SIZE)
      file  = io(zip)
      entry = entries(file).find { |e| File.basename(e.name).match?(pattern) }
      return unless entry
      raise ArgumentError, "zip member #{entry.name} is too big" if entry.size > max

      data = at(file, data_offset(file, entry), entry.csize)
      case entry.compression
      when 0 then capped(data, entry.name, max)
      when 8 then inflate(data, entry.name, max)
      else raise ArgumentError, "zip member #{entry.name}: compression method #{entry.compression}"
      end
    end

    # The Entry of each member of +file+.
    def entries(file)
      directory, count = directory(file)
      pos = 0
      Array.new(count) do
        entry, pos = entry_at(directory, pos)
        entry
      end
    end

    # The central directory of +file+ and the number of its entries.
    def directory(file)
      tail = at(file, [file.size - TAIL, 0].max, TAIL)
      eocd = tail.rindex(EOCD)
      raise ArgumentError, 'not a zip archive' unless eocd && tail.bytesize >= eocd + 22

      count, length, offset = tail.byteslice(eocd + 10, 10).unpack('vVV')
      [at(file, offset, length), count]
    end

    # The Entry at +pos+ of the central +directory+, and where the next one is.
    def entry_at(directory, pos)
      raise ArgumentError, 'broken zip directory' unless directory.byteslice(pos, 46)&.bytesize == 46 &&
                                                         directory.byteslice(pos, 4) == CENTRAL

      method, = directory.byteslice(pos + 10, 2).unpack('v')
      csize, size, name_len, extra_len, comment_len = directory.byteslice(pos + 20, 14).unpack('VVvvv')
      offset, = directory.byteslice(pos + 42, 4).unpack('V')
      name = directory.byteslice(pos + 46, name_len).to_s
      [Entry.new(name: name, compression: method, csize: csize, size: size, offset: offset),
       pos + 46 + name_len + extra_len + comment_len]
    end

    # Where the data of +entry+ starts in +file+, after its local header.
    def data_offset(file, entry)
      header = at(file, entry.offset, 30)
      raise ArgumentError, "zip member #{entry.name}: no local header" unless header.bytesize == 30 &&
                                                                              header.start_with?(LOCAL)

      name_len, extra_len = header.byteslice(26, 4).unpack('vv')
      entry.offset + 30 + name_len + extra_len
    end

    # At most +length+ bytes of +file+ from +pos+.
    def at(file, pos, length)
      file.seek(pos)
      file.read(length).to_s.b
    end

    # +zip+ as an IO: a file as it is, a String in a StringIO.
    def io(zip) = zip.respond_to?(:read) ? zip : StringIO.new(zip.b)

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
