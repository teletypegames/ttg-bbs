# frozen_string_literal: true

require 'json'
require 'fileutils'

# The inbox file: one JSON line a message (MessageModel), appended under a
# Mutex, so concurrent callers never mix their lines.
class InboxRepository
  def initialize(path)
    @path = path
    @mu   = Mutex.new
  end

  # Appends +message+; true when it is written, false (and a warning) when
  # the file could not be.
  def append(message)
    @mu.synchronize do
      FileUtils.mkdir_p(File.dirname(@path))
      File.open(@path, 'a') { |f| f.puts(JSON.generate(message.to_h.compact)) }
    end
    true
  rescue SystemCallError => e
    warn "Inbox error: #{e.class}: #{e.message}"
    false
  end

  # The last +limit+ messages, the newest first; a line that is not JSON is
  # skipped.
  def last(limit)
    return [] unless File.exist?(@path)

    File.readlines(@path, chomp: true).last(limit).reverse.filter_map do |line|
      MessageModel.from_h(JSON.parse(line).transform_keys(&:to_sym))
    rescue JSON::ParserError
      nil
    end
  rescue SystemCallError => e
    warn "Inbox error: #{e.class}: #{e.message}"
    []
  end
end
