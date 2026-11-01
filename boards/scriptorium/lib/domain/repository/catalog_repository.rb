# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'sqlite3'
require 'zlib'

# The Project Gutenberg catalog in SQLite (data/catalog.sqlite3): the
# books, the bookshelves and a full-text index of titles and authors (FTS5;
# an indexed LIKE where the SQLite has no FTS5). Nothing of it is held in
# Ruby: every list is a query. #import builds a new database from
# pg_catalog.csv.gz next to the old one and swaps it in, so callers read the
# old catalog meanwhile. One connection, read-only, behind a Mutex.
class CatalogRepository
  COLUMNS = 'id, title, authors, language, issued, subjects, bookshelves'
  # The same, of the books table under the name b.
  B_COLUMNS = COLUMNS.split(', ').map { |c| "b.#{c}" }.join(', ')

  def initialize(path)
    @path = path
    @lock = Mutex.new
    @db   = nil
    @fts  = false
    @count = nil
    open_db if File.exist?(path)
  end

  def ready? = @lock.synchronize { !@db.nil? }

  # When the catalog was last imported, or nil.
  def imported_at = File.exist?(@path) ? File.mtime(@path) : nil

  # The number of books, counted when the catalog was opened.
  def count = @count || 0

  def book(id)
    row = query("SELECT #{COLUMNS} FROM books WHERE id = ?", [Integer(id)]).first
    row && BookModel.from_row(row)
  rescue ArgumentError, TypeError
    nil
  end

  # The books of +ids+ in the order given; the ones not in the catalog are
  # left out.
  def books(ids)
    ids = ids.map(&:to_i)
    return [] if ids.empty?

    rows = query("SELECT #{COLUMNS} FROM books WHERE id IN (#{(['?'] * ids.size).join(',')})", ids)
    by_id = rows.to_h { |r| [r['id'], BookModel.from_row(r)] }
    ids.filter_map { |id| by_id[id] }
  end

  # At most +limit+ books whose title or author has every word of +words+
  # (as a word prefix), in +language+ when one is given.
  def search(words, language: nil, limit: 100)
    return [] if words.empty?

    lang_sql = language ? ' AND instr(b.language, ?) > 0' : ''
    lang     = language ? [language] : []
    rows = @fts ? match(words, lang_sql, lang, limit) : like(words, lang_sql, lang, limit)
    rows.map { |r| BookModel.from_row(r) }
  end

  # The bookshelves, the older named ones first, then the categories.
  def shelves
    query('SELECT id, name, books FROM shelves ORDER BY name LIKE \'Category: %\', name').map do |r|
      ShelfModel.new(id: r['id'], kind: :bookshelf, name: r['name'], count: r['books'])
    end
  end

  # The first +limit+ books of bookshelf +shelf_id+, lowest numbers first:
  # the oldest ebooks of Project Gutenberg are its best known ones.
  def shelf_books(shelf_id, limit: 200)
    query("SELECT #{B_COLUMNS} FROM shelf_books s JOIN books b ON b.id = s.book_id " \
          'WHERE s.shelf_id = ? ORDER BY b.id LIMIT ?', [shelf_id, limit]).map { |r| BookModel.from_row(r) }
  end

  # Builds the catalog from +csv_gz+ (pg_catalog.csv.gz) and swaps it in.
  # Returns the number of books, or nil when the file could not be read.
  def import(csv_gz)
    tmp = "#{@path}.new"
    n = build(tmp, csv_gz)
    swap(tmp)
    n
  rescue StandardError => e
    warn "scriptorium-bbs: catalog import: #{e.class}: #{e.message}"
    FileUtils.rm_f(tmp)
    nil
  end

  private

  # The full-text search: every word a prefix, best matches first.
  def match(words, lang_sql, lang, limit)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    query("SELECT #{B_COLUMNS} FROM books_fts f JOIN books b ON b.id = f.rowid WHERE books_fts MATCH ?#{lang_sql} " \
          'ORDER BY bm25(books_fts, 10.0, 5.0), b.id LIMIT ?', [terms, *lang, limit])
  end

  # The search of an SQLite without FTS5: every word somewhere.
  def like(words, lang_sql, lang, limit)
    likes = words.map { ' AND b.search LIKE ?' }.join
    query("SELECT #{B_COLUMNS} FROM books b WHERE 1#{likes}#{lang_sql} ORDER BY b.id LIMIT ?",
          [*words.map { |w| "%#{w.downcase}%" }, *lang, limit])
  end

  # Writes a new catalog database at +tmp+ from +csv_gz+; the number of
  # books.
  def build(tmp, csv_gz)
    FileUtils.rm_f(tmp)
    db = SQLite3::Database.new(tmp)
    fill(db, csv_gz, create_schema(db))
  ensure
    db.close if db && !db.closed?
  end

  # Puts the database at +tmp+ in the place of the open one.
  def swap(tmp)
    @lock.synchronize do
      @db&.close
      File.rename(tmp, @path)
      @db = nil
      open_db
    end
  end

  def open_db
    db = SQLite3::Database.new(@path, readonly: true)
    db.results_as_hash = true
    db.busy_timeout = 5000
    db.execute('PRAGMA cache_size = -2000')
    @fts   = !db.execute("SELECT 1 FROM sqlite_master WHERE name = 'books_fts'").empty?
    @count = db.execute('SELECT COUNT(*) AS n FROM books').first['n']
    @db    = db
  rescue SQLite3::Exception => e
    warn "scriptorium-bbs: #{@path}: #{e.class}: #{e.message}"
    @db = nil
  end

  def query(sql, params = [])
    @lock.synchronize do
      return [] unless @db

      @db.execute(sql, params)
    end
  rescue SQLite3::Exception => e
    warn "scriptorium-bbs: catalog: #{e.class}: #{e.message}"
    []
  end

  # The tables; true when the SQLite has FTS5.
  def create_schema(db)
    db.execute_batch(<<~SQL)
      PRAGMA journal_mode = OFF;
      PRAGMA synchronous = OFF;
      CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, authors TEXT, language TEXT, issued TEXT,
                          subjects TEXT, bookshelves TEXT, search TEXT);
      CREATE TABLE memberships (name TEXT, book_id INTEGER);
      CREATE TABLE shelves (id INTEGER PRIMARY KEY, name TEXT UNIQUE, books INTEGER);
      CREATE TABLE shelf_books (shelf_id INTEGER, book_id INTEGER);
    SQL
    db.execute("CREATE VIRTUAL TABLE books_fts USING fts5(title, authors, content='books', content_rowid='id', " \
               "tokenize='unicode61 remove_diacritics 2')")
    true
  rescue SQLite3::SQLException
    false
  end

  def fill(db, csv_gz, fts)
    n = db.transaction { insert_books(db, csv_gz, fts).tap { index_shelves(db, fts) } }
    db.execute('VACUUM')
    n
  end

  # The Text rows of the catalog file into books and memberships; the
  # number of books.
  def insert_books(db, csv_gz, fts)
    book   = db.prepare('INSERT INTO books VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    member = db.prepare('INSERT INTO memberships VALUES (?, ?)')
    n = 0
    each_book(csv_gz) do |values|
      book.execute(*values, fts ? nil : "#{values[1]} #{values[2]}".downcase)
      values[6].split('; ').each { |s| member.execute(s.strip, values[0]) unless s.strip.empty? }
      n += 1
    end
    n
  ensure
    book&.close
    member&.close
  end

  # Yields [id, title, authors, language, issued, subjects, bookshelves] of
  # every Text row of +csv_gz+, the remote text cleaned of control
  # characters (a title keeps its line breaks: a subtitle is on its own).
  def each_book(csv_gz)
    Zlib::GzipReader.open(csv_gz, encoding: Encoding::UTF_8) do |gz|
      CSV.new(gz, headers: true).each do |row|
        next unless row['Type'] == 'Text'

        id = Integer(row['Text#'], exception: false) or next
        yield [id, clean(row['Title'].to_s.gsub(/\r\n?/, "\n").strip, keep_newlines: true),
               *%w[Authors Language Issued Subjects Bookshelves].map { |c| clean(row[c]) }]
      end
    end
  end

  def clean(text, keep_newlines: false) = BBS::Text.clean(text, keep_newlines: keep_newlines)

  def index_shelves(db, fts)
    db.execute_batch(<<~SQL)
      INSERT INTO shelves (name, books) SELECT name, COUNT(*) FROM memberships GROUP BY name;
      INSERT INTO shelf_books SELECT s.id, m.book_id FROM memberships m JOIN shelves s ON s.name = m.name;
      DROP TABLE memberships;
      CREATE INDEX shelf_books_shelf ON shelf_books (shelf_id, book_id);
    SQL
    db.execute("INSERT INTO books_fts (books_fts) VALUES ('rebuild')") if fts
  end
end
