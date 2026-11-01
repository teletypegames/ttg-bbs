# frozen_string_literal: true

require 'test_helper'
require 'csv'
require 'zlib'

class CatalogRepositoryTest < Minitest::Test
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
    @catalog = CatalogRepository.new(path('catalog.sqlite3'))
    capture_io { @count = @catalog.import(@csv) }
  end

  def test_imports_the_texts_with_their_fields_cleaned
    assert_equal 2, @count
    assert_equal 2, @catalog.count
    book = @catalog.book(1342)

    assert_equal "Pride and Prejudice\nA novel[2J", book.title
    assert_equal 'Jane Austen', book.author
  end

  def test_searches_titles_and_authors_by_word_prefix
    assert_equal [84], @catalog.search(%w[shell]).map(&:id)
    assert_equal [1342], @catalog.search(%w[pride aust], language: 'en').map(&:id)
    assert_empty @catalog.search(%w[pride], language: 'fr')
  end

  def test_gathers_the_bookshelves
    novels = @catalog.shelves.find { |s| s.label == 'Novels' }

    assert_equal 2, novels.count
    assert_equal [84, 1342], @catalog.shelf_books(novels.id).map(&:id)
    assert_equal [84, 1342], @catalog.books([84, 7, 1342]).map(&:id)
  end
end
