# frozen_string_literal: true

require 'sqlite3'

# The full text of every RFC (and IEN) on the disk, indexed in SQLite
# (data/fulltext.sqlite3): a contentless FTS5 table, so only the index is
# stored, not the text a second time, and a docs table with the size and
# mtime each text was indexed at, so a sync re-indexes only what changed.
# One writer (the mirror's thread) and one reader connection, each behind
# its own Mutex; WAL lets them work at once.
class FulltextRepository
  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS docs (number INTEGER PRIMARY KEY, size INTEGER, mtime INTEGER);
    CREATE VIRTUAL TABLE IF NOT EXISTS text_fts USING fts5(body, content='', contentless_delete=1,
                                                           tokenize='unicode61 remove_diacritics 2');
  SQL

  def initialize(path)
    @path  = path
    @write = Mutex.new
    @read  = Mutex.new
  end

  # How many texts are indexed.
  def count = reader { |db| db.get_first_value('SELECT COUNT(*) FROM docs') }.to_i

  def ready? = count.positive?

  # The texts indexed, with the size and mtime they had: { 854 => [57_000, 1700000000] }.
  def stats = reader { |db| db.execute('SELECT number, size, mtime FROM docs').to_h { |n, s, m| [n, [s, m]] } } || {}

  # Indexes +body+ as the text of +number+ (replacing what was there), with
  # the +size+ and +mtime+ of its file.
  def put(number, body, size:, mtime:)
    writer do |db|
      db.transaction do
        db.execute('DELETE FROM text_fts WHERE rowid = ?', [number])
        db.execute('INSERT INTO text_fts (rowid, body) VALUES (?, ?)', [number, body])
        db.execute('INSERT OR REPLACE INTO docs VALUES (?, ?, ?)', [number, size, mtime])
      end
    end
  end

  # The numbers of at most +limit+ texts that have every word of +words+
  # (as a word prefix), best matches first.
  def search(words, limit:)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    reader do |db|
      db.execute('SELECT rowid FROM text_fts WHERE text_fts MATCH ? ORDER BY bm25(text_fts) LIMIT ?', [terms, limit]).flatten
    end || []
  end

  private

  def writer(&) = @write.synchronize { use(@writer ||= connect, &) }

  def reader(&)
    return nil unless File.exist?(@path)

    @read.synchronize { use(@reader ||= connect, &) }
  end

  def use(db)
    yield db
  rescue SQLite3::Exception => e
    BBS.log('fulltext', "#{e.class}: #{e.message}")
    nil
  end

  def connect
    FileUtils.mkdir_p(File.dirname(@path))
    db = SQLite3::Database.new(@path)
    db.busy_timeout = 10_000
    db.execute('PRAGMA journal_mode = WAL')
    db.execute('PRAGMA cache_size = -4000')
    db.execute_batch(SCHEMA)
    db
  end
end
