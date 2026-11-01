# frozen_string_literal: true

require 'time'

# The books opened on the board, one row a read (the reads table of
# data/scriptorium.sqlite3), and how many times each was opened.
class ReadRepository
  # The schema steps of the reads table, for BBS::SQLite#migrate.
  MIGRATIONS = [<<~SQL].freeze
    CREATE TABLE reads (id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL, at TEXT NOT NULL);
    CREATE INDEX reads_book ON reads (book_id);
  SQL

  def initialize(db)
    @db = db
  end

  def add(book_id, at: Time.now.utc)
    @db.insert('INSERT INTO reads (book_id, at) VALUES (?, ?)', Integer(book_id), at.utc.iso8601)
  end

  def count(book_id) = @db.get('SELECT COUNT(*) AS n FROM reads WHERE book_id = ?', Integer(book_id))['n']

  def empty? = @db.get('SELECT 1 AS one FROM reads LIMIT 1').nil?

  # The +n+ most read books as [id, reads], most read first.
  def top(n)
    @db.query('SELECT book_id, COUNT(*) AS n FROM reads GROUP BY book_id ORDER BY n DESC, book_id LIMIT ?', n)
       .map { |row| [row['book_id'], row['n']] }
  end
end
