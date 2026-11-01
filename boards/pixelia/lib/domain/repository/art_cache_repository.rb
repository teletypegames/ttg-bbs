# frozen_string_literal: true

require 'digest'
require 'fileutils'

# The art files fetched from 16colo.rs, kept on disk in data/cache/ under a
# digest of their pack and name, at most +max_bytes+ of them: when a new file
# would go over, the least recently used ones go. A file read is used, so its
# mtime is set to now; the sizes and times are also kept in memory.
class ArtCacheRepository
  def initialize(dir, max_bytes:)
    @dir       = dir
    @max_bytes = max_bytes
    @lock      = Mutex.new
    @entries   = {}
    scan
  end

  # The bytes kept for +key+, or nil.
  def read(key)
    path = path(key)
    @lock.synchronize do
      return nil unless @entries.key?(path)

      data = File.binread(path)
      now  = Time.now
      File.utime(now, now, path)
      @entries[path][:used] = now
      data
    end
  rescue SystemCallError => e
    warn "pixelia: #{path}: #{e.class}: #{e.message}"
    @lock.synchronize { @entries.delete(path) }
    nil
  end

  # Keeps +data+ for +key+, making room first.
  def write(key, data)
    return if data.bytesize > @max_bytes

    path = path(key)
    @lock.synchronize do
      evict(data.bytesize)
      FileUtils.mkdir_p(@dir)
      tmp = "#{path}.#{Process.pid}.tmp"
      File.binwrite(tmp, data)
      File.rename(tmp, path)
      @entries[path] = { size: data.bytesize, used: Time.now }
    end
  rescue SystemCallError => e
    warn "pixelia: #{path}: #{e.class}: #{e.message}"
  end

  def size = @lock.synchronize { @entries.values.sum { |e| e[:size] } }

  private

  def path(key) = File.join(@dir, "#{Digest::SHA256.hexdigest(key)[0, 32]}.art")

  def evict(incoming)
    total = @entries.values.sum { |e| e[:size] }
    @entries.sort_by { |_, e| e[:used] }.each do |path, entry|
      break if total + incoming <= @max_bytes

      FileUtils.rm_f(path)
      @entries.delete(path)
      total -= entry[:size]
    end
  end

  def scan
    Dir.glob(File.join(@dir, '*.art')).each do |path|
      stat = File.stat(path)
      @entries[path] = { size: stat.size, used: stat.mtime }
    end
  rescue SystemCallError => e
    warn "pixelia: #{@dir}: #{e.class}: #{e.message}"
  end
end
