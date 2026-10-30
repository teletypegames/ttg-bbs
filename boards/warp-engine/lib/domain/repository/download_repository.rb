# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

# The downloads that went through, one JSON line each in data/downloads.jsonl,
# and their count by title.
class DownloadRepository
  def initialize(path)
    @path   = path
    @counts = Hash.new(0)
    @lock   = Mutex.new
    load
  end

  def count(key) = @lock.synchronize { @counts[key] }

  def add(key, version:, protocol:)
    line = JSON.generate(at: Time.now.iso8601, title: key, version: version, protocol: protocol)
    @lock.synchronize do
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, 'a') { |f| f.puts(line) }
      @counts[key] += 1
    end
  rescue SystemCallError => e
    warn "warp-engine-bbs: #{@path}: #{e.class}: #{e.message}"
  end

  private

  def load
    return unless File.exist?(@path)

    File.foreach(@path) do |line|
      key = JSON.parse(line)['title']
      @counts[key] += 1 if key
    rescue JSON::ParserError
      next
    end
  rescue SystemCallError => e
    warn "warp-engine-bbs: #{@path}: #{e.class}: #{e.message}"
  end
end
