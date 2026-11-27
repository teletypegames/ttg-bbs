# frozen_string_literal: true

require 'test_helper'

class CatalogMigrationTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('scriptorium-migration')
    @file = File.join(@dir, 'catalog.sqlite3')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_catalog_of_the_old_names_keeps_its_rows
    write_old_catalog

    db = Rubbs::Common::Storage::Database.open(@file, CATALOG_MIGRATIONS)

    refute db.table_exists?(:shelves)
    refute db.table_exists?(:shelf_books)
    assert_equal [{ id: 3, name: 'Category: Novels', books: 1 }], db[:bookshelves].all
    assert_equal [{ bookshelf_id: 3, book_id: 84 }], db[:bookshelf_books].all
    assert_equal 3, db.fetch('PRAGMA user_version').single_value
  ensure
    close(db) if db
  end

  def test_a_catalog_of_version_two_keeps_its_rows
    write_version_two_catalog

    db = Rubbs::Common::Storage::Database.open(@file, CATALOG_MIGRATIONS)

    refute db.table_exists?(:selection_books)
    assert_equal [{ bookshelf_id: 3, book_id: 84 }], db[:bookshelf_books].all
    assert_equal 3, db.fetch('PRAGMA user_version').single_value
  ensure
    close(db) if db
  end

  def test_a_new_catalog_has_the_new_names
    db = Rubbs::Common::Storage::Database.open(@file, CATALOG_MIGRATIONS)

    assert CatalogSchema.current?(db)
    refute db.table_exists?(:shelves)
  ensure
    close(db) if db
  end

  private

  def write_old_catalog
    old = Rubbs::Common::Storage::Database.open(@file)
    old.run('CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, authors TEXT, language TEXT, issued TEXT, ' \
            'subjects TEXT, bookshelves TEXT, search TEXT)')
    old.run('CREATE TABLE shelves (id INTEGER PRIMARY KEY, name TEXT UNIQUE, books INTEGER)')
    old.run('CREATE TABLE shelf_books (shelf_id INTEGER, book_id INTEGER)')
    old.run('CREATE INDEX shelf_books_shelf ON shelf_books (shelf_id, book_id)')
    old[:shelves].insert(id: 3, name: 'Category: Novels', books: 1)
    old[:shelf_books].insert(shelf_id: 3, book_id: 84)
    old.run('PRAGMA user_version = 1')
    close(old)
  end

  def write_version_two_catalog
    old = Rubbs::Common::Storage::Database.open(@file)
    old.run('CREATE TABLE books (id INTEGER PRIMARY KEY, title TEXT, authors TEXT, language TEXT, issued TEXT, ' \
            'subjects TEXT, bookshelves TEXT, search TEXT)')
    old.run('CREATE TABLE bookshelves (id INTEGER PRIMARY KEY, name TEXT UNIQUE, books INTEGER)')
    old.run('CREATE TABLE selection_books (selection_id INTEGER, book_id INTEGER)')
    old.run('CREATE INDEX selection_books_selection ON selection_books (selection_id, book_id)')
    old[:bookshelves].insert(id: 3, name: 'Category: Novels', books: 1)
    old[:selection_books].insert(selection_id: 3, book_id: 84)
    old.run('PRAGMA user_version = 2')
    close(old)
  end

  def close(db)
    db.disconnect
    Sequel::DATABASES.delete(db)
  end
end
