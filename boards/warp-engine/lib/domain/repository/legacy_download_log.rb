# frozen_string_literal: true

require 'json'

# The download log of the board before SQLite, data/downloads.jsonl (one
# JSON object a line: at, title, version, protocol). Read once into an empty
# downloads table, in one transaction, then renamed to .imported so it is
# never read again; a line that does not parse is skipped, not the file.
class LegacyDownloadLog
  def initialize(path, downloads)
    @path      = path
    @downloads = downloads
  end

  # Imports the log when it exists and the table is empty. Returns the
  # counts [imported, skipped], or nil when there was nothing to do.
  def import
    return unless File.exist?(@path) && @downloads.empty?

    counts = @downloads.transaction { File.foreach(@path).partition { |line| add(line) }.map(&:size) }
    File.rename(@path, "#{@path}.imported")
    BBS.log('downloads', "imported #{counts[0]} from #{File.basename(@path)} (#{counts[1]} skipped)")
    counts
  end

  private

  # Adds the download of +line+; false when the line is not one.
  def add(line)
    row = JSON.parse(line)
    return false unless row.is_a?(Hash) && row['title'].is_a?(String) && row['at'].is_a?(String)

    @downloads.add(row['title'], version: row['version'], protocol: row['protocol'], at: row['at'])
    true
  rescue JSON::ParserError
    false
  end
end
