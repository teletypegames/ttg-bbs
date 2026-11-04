# frozen_string_literal: true

# The schemas of the board's two SQLite files, one step per version
# (BBS::Database.migrate, counted in PRAGMA user_version).

# data/scriptorium.sqlite3: the reads (ReadModel).
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE reads (id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL, at TEXT NOT NULL);
  CREATE INDEX reads_book ON reads (book_id);
SQL

# The tables of the Project Gutenberg catalog (data/catalog.sqlite3):
# BookModel, BookshelfModel, ShelfBookModel, and the full-text index of the
# titles and authors (FTS5; a search column for LIKE where the SQLite has no
# FTS5). The catalog is not migrated but built whole (CatalogBuilder,
# BookModel.rebuild): #create makes the tables anew, #index indexes the
# shelves once they are filled. A build gathers the bookshelves of the books
# in a temporary table of its connection, MEMBERSHIPS, gone when it is done.
module CatalogSchema
  TABLES = [
    'CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, authors TEXT, language TEXT, issued TEXT, ' \
    'subjects TEXT, bookshelves TEXT, search TEXT)',
    'CREATE TABLE shelves (id INTEGER PRIMARY KEY, name TEXT UNIQUE, books INTEGER)',
    'CREATE TABLE shelf_books (shelf_id INTEGER, book_id INTEGER)'
  ].freeze
  FTS = "CREATE VIRTUAL TABLE books_fts USING fts5(title, authors, content='books', content_rowid='id', " \
        "tokenize='unicode61 remove_diacritics 2')"
  INDEX = 'CREATE INDEX shelf_books_shelf ON shelf_books (shelf_id, book_id)'
  MEMBERSHIPS = 'CREATE TEMPORARY TABLE memberships (name TEXT, book_id INTEGER)'
  # The tables to drop, the full-text index before its content.
  DROP = %i[books_fts shelf_books shelves books].freeze

  # Whether +db+ has the tables of the catalog.
  def self.current?(db) = (%w[books shelves shelf_books] - db[:sqlite_master].where(type: 'table').select_map(:name)).empty?

  # Drops the tables of +db+ and makes them anew, empty. True when the
  # SQLite has FTS5.
  def self.create(db)
    DROP.each { |table| db.drop_table?(table) }
    TABLES.each { |sql| db.run(sql) }
    fts(db)
  end

  # Makes the full-text index; false when the SQLite has no FTS5.
  def self.fts(db)
    db.run(FTS)
    true
  rescue Sequel::DatabaseError
    false
  end

  def self.index(db) = db.run(INDEX)
end

# data/catalog.sqlite3: the empty tables of a new file, so the models bind.
CATALOG_MIGRATIONS = [lambda { |db|
  next if CatalogSchema.current?(db)

  CatalogSchema.create(db)
  CatalogSchema.index(db)
}].freeze
