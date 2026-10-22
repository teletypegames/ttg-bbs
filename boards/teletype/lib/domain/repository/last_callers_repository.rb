# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'

# Append-only log of every finished call. Stored as CSV so it survives
# restarts; the whole log stays in memory, it is the board's call history
# (caller numbers, per-name stats, the top callers). Rows written before the
# call length was logged have no seconds.
class LastCallersRepository
  Caller = Struct.new(:timestamp, :username, :session_id, :seconds) do
    def time = Time.parse(timestamp)
  end

  def initialize(path)
    @path    = path
    @mu      = Mutex.new
    @entries = load
  end

  def record(username, session_id, seconds = nil)
    entry = Caller.new(Time.now.iso8601, username, session_id, seconds&.to_i&.to_s)
    @mu.synchronize do
      @entries << entry
      FileUtils.mkdir_p(File.dirname(@path))
      CSV.open(@path, 'a') { |csv| csv << entry.to_a }
    end
    entry
  end

  def recent(n = 10)
    @mu.synchronize { @entries.last(n).reverse }
  end

  def all
    @mu.synchronize { @entries.dup }
  end

  def count
    @mu.synchronize { @entries.size }
  end

  private

  def load
    return [] unless File.exist?(@path)
    raw = File.binread(@path).force_encoding(Encoding::UTF_8).scrub
    CSV.parse(raw).filter_map { |row| Caller.new(*row.first(4)) if row[0] && row[1] }
  rescue StandardError
    []
  end
end
