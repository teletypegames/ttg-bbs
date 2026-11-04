# frozen_string_literal: true

require 'json'
require 'time'

# The reads the board logged before SQLite: data/reads.jsonl, one JSON line
# a read ({"at":"2026-11-01T00:19:50Z","book":1342}). On the first start
# with the database they are imported into an empty reads table (ReadModel)
# in one transaction, a line that does not parse is skipped, and the file is
# renamed reads.jsonl.imported, so it is imported once.
module LegacyReads
  module_function

  # Imports +path+ when the file is there and no read is counted yet.
  # Returns [imported, skipped], or nil when there was nothing to do.
  def import(path)
    return unless File.exist?(path) && ReadModel.none?

    counts = ReadModel.db.transaction { File.foreach(path).map { |line| add(line) unless line.strip.empty? } }.tally
    File.rename(path, "#{path}.imported")
    imported = counts.fetch(true, 0)
    skipped  = counts.fetch(false, 0)
    BBS.log('reads', "imported #{imported} reads from #{File.basename(path)} (#{skipped} skipped)")
    [imported, skipped]
  end

  # Adds the read of one line; true, or false when the line is not one.
  def add(line)
    row = JSON.parse(line)
    ReadModel.add(Integer(row.fetch('book')), at: Time.iso8601(row.fetch('at')))
    true
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError, NoMethodError
    false
  end
end
