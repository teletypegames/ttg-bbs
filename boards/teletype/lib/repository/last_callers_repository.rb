# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'

# Append-only log of the last N logins. Stored as CSV so it survives restarts.
class LastCallersRepository
  Caller = Struct.new(:timestamp, :username, :session_id)

  def initialize(path, limit: 50)
    @path  = path
    @limit = limit
    @mu    = Mutex.new
    @entries = load
  end

  def record(username, session_id)
    entry = Caller.new(Time.now.iso8601, username, session_id)
    @mu.synchronize do
      @entries << entry
      @entries.shift while @entries.size > @limit
      FileUtils.mkdir_p(File.dirname(@path))
      CSV.open(@path, 'a') { |csv| csv << [entry.timestamp, entry.username, entry.session_id] }
    end
    entry
  end

  def recent(n = 10)
    @mu.synchronize { @entries.last(n).reverse }
  end

  private

  def load
    return [] unless File.exist?(@path)
    CSV.read(@path).map { |row| Caller.new(*row) }
  rescue StandardError
    []
  end
end
