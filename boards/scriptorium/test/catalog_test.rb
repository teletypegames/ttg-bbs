# frozen_string_literal: true

require 'test_helper'
require 'csv'
require 'zlib'

class CatalogTest < Minitest::Test
  include TempDir

  HEADERS = %w[Text# Type Issued Title Language Authors Subjects LoCC Bookshelves].freeze
  ROWS = [
    ['1342', 'Text', '1998-06-01', "Pride and Prejudice\r\nA novel\e[2J", 'en', 'Austen, Jane, 1775-1817‮',
     'England -- Fiction', 'PR', 'Best Books Ever Listings; Category: Novels'],
    ['84', 'Text', '1993-10-01', 'Frankenstein', 'en', 'Shelley, Mary Wollstonecraft, 1797-1851',
     'Horror tales', 'PR', 'Category: Novels'],
    ['999', 'Sound', '2000-01-01', 'A recording', 'en', '', '', '', ''],
    ['x', 'Text', '', 'No number', 'en', '', '', '', '']
  ].freeze

  def setup
    super
    @csv = path('pg_catalog.csv.gz')
    Zlib::GzipWriter.open(@csv) { |gz| gz.write(CSV.generate { |c| [HEADERS, *ROWS].each { |r| c << r } }) }
    capture_io { @count = CatalogBuilder.new.build(@csv) }
  end

  def test_imports_the_texts_with_their_fields_cleaned
    assert_equal 2, @count
    assert_equal 2, BookModel.total
    book = BookModel.book(1342)

    assert_equal "Pride and Prejudice\nA novel[2J", book.title
    assert_equal 'Jane Austen', book.author
  end

  def test_searches_titles_and_authors_by_word_prefix
    assert_equal [84], BookModel.search(%w[shell]).map(&:id)
    assert_equal [1342], BookModel.search(%w[pride aust], language: 'en').map(&:id)
    assert_empty BookModel.search(%w[pride], language: 'fr')
  end

  def test_gathers_the_bookshelves
    novels = BookshelfModel.all_shelves.find { |s| s.label == 'Novels' }

    assert_equal 2, novels.count
    assert_equal ['Best Books Ever Listings', 'Category: Novels'], BookshelfModel.all_shelves.map(&:name)
    assert_equal [84, 1342], ShelfBookModel.books_on(novels.id).map(&:id)
    assert_equal [84, 1342], BookModel.books([84, 7, 1342]).map(&:id)
  end

  def test_a_new_import_replaces_the_catalog_and_a_failed_one_keeps_it
    Zlib::GzipWriter.open(@csv) { |gz| gz.write(CSV.generate { |c| [HEADERS, ROWS[1]].each { |r| c << r } }) }
    capture_io { assert_equal 1, CatalogBuilder.new.build(@csv) }
    assert_equal 1, BookModel.total
    assert_nil BookModel.book(1342)
    assert_equal ['Category: Novels'], BookshelfModel.all_shelves.map(&:name)
    File.write(@csv, 'not gzip')
    assert_raises(StandardError) { CatalogBuilder.new.build(@csv) }
    assert_equal [84], BookModel.search(%w[frank]).map(&:id)
  end

  def test_callers_read_the_old_catalog_while_the_new_one_is_built
    reader = Rubbs::Common::Storage::Database.open(path('catalog.sqlite3'))
    during = BookModel.rebuild { |_fts| reader[:books].where(id: 84).get(:title) }
    assert_equal 'Frankenstein', during
    refute BookModel.ready?
  ensure
    close_database(reader) if reader
  end
end
