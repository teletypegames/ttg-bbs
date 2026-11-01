# frozen_string_literal: true

require 'time'

# The downloads that went through, a row each in the downloads table, and
# their count by title.
class DownloadRepository
  SCHEMA = <<~SQL
    CREATE TABLE downloads (
      id       INTEGER PRIMARY KEY,
      at       TEXT NOT NULL,
      title    TEXT NOT NULL,
      version  TEXT NOT NULL DEFAULT '',
      protocol TEXT NOT NULL
    );
    CREATE INDEX downloads_title ON downloads (title);
  SQL

  def initialize(db)
    @db = db
    @db.migrate(SCHEMA)
  end

  def count(key) = @db.get('SELECT count(*) AS n FROM downloads WHERE title = ?', key)['n']

  def empty? = @db.get('SELECT 1 AS one FROM downloads LIMIT 1').nil?

  def add(key, version:, protocol:, at: Time.now.iso8601)
    @db.insert('INSERT INTO downloads (at, title, version, protocol) VALUES (?, ?, ?, ?)',
               at, key, version.to_s, protocol.to_s)
  end

  def transaction(&) = @db.transaction(&)
end
