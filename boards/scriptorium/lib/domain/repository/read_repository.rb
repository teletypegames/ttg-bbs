# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

# The books opened on the board (data/reads.jsonl, one JSON line a read)
# and how many times each was opened, counted from the file at start.
class ReadRepository
  def initialize(path)
    @path   = path
    @lock   = Mutex.new
    @counts = Hash.new(0)
    load
  end

  def add(book_id)
    @lock.synchronize do
      @counts[book_id] += 1
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, 'a') { |f| f.puts(JSON.generate('at' => Time.now.utc.iso8601, 'book' => book_id)) }
    end
  rescue SystemCallError => e
    warn "scriptorium: #{@path}: #{e.class}: #{e.message}"
  end

  def count(book_id) = @lock.synchronize { @counts[book_id] }

  # The +n+ most read books as [id, reads], most read first.
  def top(n) = @lock.synchronize { @counts.sort_by { |id, c| [-c, id] }.first(n) }

  private

  def load
    return unless File.exist?(@path)

    File.foreach(@path) do |line|
      id = JSON.parse(line)['book']
      @counts[id] += 1 if id.is_a?(Integer)
    rescue JSON::ParserError
      next
    end
  rescue SystemCallError => e
    warn "scriptorium: #{@path}: #{e.class}: #{e.message}"
  end
end
