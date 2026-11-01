# frozen_string_literal: true

require 'time'

# The oneliners wall: one short line per caller, newest last.
class OnelinerRepository
  Oneliner = Struct.new(:timestamp, :username, :text)

  def initialize(db) = @db = db

  def append(username, text)
    entry = Oneliner.new(Time.now.iso8601, username, text)
    @db.insert('INSERT INTO oneliners (timestamp, username, text) VALUES (?, ?, ?)', *entry.to_a)
    entry
  end

  # The newest +n+, newest first.
  def recent(n)
    @db.query('SELECT * FROM oneliners ORDER BY id DESC LIMIT ?', n)
       .map { |row| Oneliner.new(row['timestamp'], row['username'], row['text']) }
  end
end
