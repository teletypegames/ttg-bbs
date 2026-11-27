# frozen_string_literal: true

# The schemas of the board's two SQLite files, one step per version
# (Rubbs::Common::Storage::Database.migrate, counted in PRAGMA user_version).

# data/scriptorium.sqlite3: the reads (ReadModel).
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE reads (id INTEGER PRIMARY KEY, book_id INTEGER NOT NULL, at TEXT NOT NULL);
  CREATE INDEX reads_book ON reads (book_id);
SQL

# The tables of the Project Gutenberg catalog (data/catalog.sqlite3):
# BookModel, BookshelfModel, BookshelfBookModel, CatalogMetaModel, and the full-text index of the
# titles and authors (FTS5; a search column for LIKE where the SQLite has no
# FTS5). The catalog is not migrated but built whole (CatalogBuilder,
# BookModel.rebuild): #create makes the tables anew, #index indexes the
# bookshelves once they are filled. A build gathers the bookshelves of the books
# in a temporary table of its connection, MEMBERSHIPS, gone when it is done.
module CatalogSchema
  TABLES = [
    'CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, authors TEXT, language TEXT, issued TEXT, ' \
    'subjects TEXT, bookshelves TEXT, search TEXT)',
    'CREATE TABLE bookshelves (id INTEGER PRIMARY KEY, name TEXT UNIQUE, books INTEGER)',
    'CREATE TABLE bookshelf_books (bookshelf_id INTEGER, book_id INTEGER)'
  ].freeze
  FTS = "CREATE VIRTUAL TABLE books_fts USING fts5(title, authors, content='books', content_rowid='id', " \
        "tokenize='unicode61 remove_diacritics 2')"
  INDEX = 'CREATE INDEX bookshelf_books_bookshelf ON bookshelf_books (bookshelf_id, book_id)'
  MEMBERSHIPS = 'CREATE TEMPORARY TABLE memberships (name TEXT, book_id INTEGER)'
  # Facts about the catalog itself (imported_at); kept across a rebuild.
  META = 'CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)'
  # The tables to drop, the full-text index before its content.
  DROP = %i[books_fts bookshelf_books bookshelves books].freeze

  # Whether +db+ has the tables of the catalog.
  def self.current?(db) = %i[books bookshelves bookshelf_books].all? { |table| db.table_exists?(table) }

  # Drops the tables of +db+ and makes them anew, empty. True when the
  # SQLite has FTS5.
  def self.create(db)
    DROP.each { |table| db.drop_table?(table) }
    TABLES.each { |sql| db.run(sql) }
    db.run(META)
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

# data/catalog.sqlite3: the empty tables of a new file, so the models bind;
# then the tables of a catalog built under older names renamed, their rows
# kept: shelves and shelf_books (version 1), selection_books (version 2).
# Version 4 adds the meta table; a catalog built before it has no import time
# and counts as stale, so the board imports it again.
CATALOG_MIGRATIONS = [
  lambda { |db|
    next if CatalogSchema.current?(db)

    CatalogSchema.create(db)
    CatalogSchema.index(db)
  },
  lambda { |db|
    next unless db.table_exists?(:shelf_books)

    db.run('DROP INDEX IF EXISTS shelf_books_shelf')
    db.drop_table?(:bookshelves, :bookshelf_books)
    db.run('ALTER TABLE shelves RENAME TO bookshelves')
    db.run('ALTER TABLE shelf_books RENAME TO bookshelf_books')
    db.run('ALTER TABLE bookshelf_books RENAME COLUMN shelf_id TO bookshelf_id')
    CatalogSchema.index(db)
  },
  lambda { |db|
    next unless db.table_exists?(:selection_books)

    db.run('DROP INDEX IF EXISTS selection_books_selection')
    db.drop_table?(:bookshelf_books)
    db.run('ALTER TABLE selection_books RENAME TO bookshelf_books')
    db.run('ALTER TABLE bookshelf_books RENAME COLUMN selection_id TO bookshelf_id')
    CatalogSchema.index(db)
  },
  ->(db) { db.run(CatalogSchema::META) }
].freeze
