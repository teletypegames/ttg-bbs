# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'

# The oneliners wall: one short line per caller, newest last. Stored as CSV
# so it survives restarts; only the last +limit+ are kept in memory.
class OnelinerRepository
  Oneliner = Struct.new(:timestamp, :username, :text)

  def initialize(path, limit: 100)
    @path    = path
    @limit   = limit
    @mu      = Mutex.new
    @entries = load
  end

  def append(username, text)
    entry = Oneliner.new(Time.now.iso8601, username, text)
    @mu.synchronize do
      @entries << entry
      @entries.shift while @entries.size > @limit
      FileUtils.mkdir_p(File.dirname(@path))
      CSV.open(@path, 'a') { |csv| csv << entry.to_a }
    end
    entry
  end

  def recent(n)
    @mu.synchronize { @entries.last(n).reverse }
  end

  private

  def load
    return [] unless File.exist?(@path)

    raw = File.binread(@path).force_encoding(Encoding::UTF_8).scrub
    CSV.parse(raw).map { |row| Oneliner.new(*row) }.last(@limit)
  rescue StandardError
    []
  end
end
