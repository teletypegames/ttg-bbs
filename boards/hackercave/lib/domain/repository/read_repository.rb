# frozen_string_literal: true

require 'time'

# The RFCs opened on the board, one row a read (the reads table of
# data/hackercave.sqlite3), and how many times each was opened.
class ReadRepository
  # The schema steps of the reads table, for BBS::SQLite#migrate.
  MIGRATIONS = [<<~SQL].freeze
    CREATE TABLE reads (id INTEGER PRIMARY KEY, rfc INTEGER NOT NULL, at TEXT NOT NULL);
    CREATE INDEX reads_rfc ON reads (rfc);
  SQL

  def initialize(db)
    @db = db
  end

  def add(number, at: Time.now.utc)
    @db.insert('INSERT INTO reads (rfc, at) VALUES (?, ?)', Integer(number), at.utc.iso8601)
  end

  def count(number) = @db.get('SELECT COUNT(*) AS n FROM reads WHERE rfc = ?', Integer(number))['n']

  # The +n+ most read RFCs as [number, reads], most read first.
  def top(n)
    @db.query('SELECT rfc, COUNT(*) AS n FROM reads GROUP BY rfc ORDER BY n DESC, rfc LIMIT ?', n)
       .map { |row| [row['rfc'], row['n']] }
  end
end
