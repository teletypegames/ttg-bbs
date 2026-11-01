# frozen_string_literal: true

require 'fileutils'
require 'sqlite3'

# The one SQLite file of the board and its one connection, behind a mutex:
# the board is one process with a thread per caller, and tips are written
# rarely. bin/tips opens the same file from its own process.
class SqliteDatabase
  def initialize(path)
    FileUtils.mkdir_p(File.dirname(path))
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db.busy_timeout = 5000
    @db.execute('PRAGMA journal_mode = WAL')
    @db.execute('PRAGMA foreign_keys = ON')
    @mutex = Mutex.new
  end

  # The rows of a query, as hashes.
  def query(sql, *args) = @mutex.synchronize { @db.execute(sql, args) }

  # The number of rows a statement changed.
  def change(sql, *args)
    @mutex.synchronize do
      @db.execute(sql, args)
      @db.changes
    end
  end

  # The block, given the connection, in one transaction.
  def transaction(&) = @mutex.synchronize { @db.transaction(&) }
end
