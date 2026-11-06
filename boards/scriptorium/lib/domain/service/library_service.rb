# frozen_string_literal: true

require 'fileutils'

# The board's library: the Classics shelf and the Project Gutenberg
# bookshelves, a search by title and author, a book's record and the books
# most read here. It keeps the catalog fresh: #refresh downloads and imports
# it when it is older than the TTL. Until the first import is done the
# Classics shelf still stands, and everything else answers :preparing.
class LibraryService
  SEARCH_LIMIT = 100
  SHELF_LIMIT  = 200
  MIN_WORD     = 2
  MAX_WORDS    = 6

  def initialize(classics:, gutenberg:, catalog_file:, ttl:)
    @classics     = classics
    @gutenberg    = gutenberg
    @catalog_file = catalog_file
    @ttl          = ttl
    @importing    = false
    @lock         = Mutex.new
  end

  def ready? = BookModel.ready?

  def importing? = @lock.synchronize { @importing }

  # The number of books in the catalog (0 before the first import).
  def count = BookModel.total

  def classics_shelf = ShelfModel.new(id: 0, kind: :classics, name: 'Classics', count: @classics.all.size)

  # The Classics shelf, then the bookshelves of the catalog.
  def shelves = [classics_shelf, *BookshelfModel.all_shelves]

  # The books of +shelf+: the curated ones in their order (the catalog's
  # records where it has them), or the first SHELF_LIMIT of a bookshelf.
  def books_on(shelf)
    return ShelfBookModel.books_on(shelf.id, limit: SHELF_LIMIT) unless shelf.classics?

    known = BookModel.books(@classics.all.map(&:id)).to_h { |b| [b.id, b] }
    @classics.all.map { |b| known[b.id] || b }
  end

  # The books whose title or author has every word of +query+; a word
  # "lang:xx" keeps to one language. :preparing before the catalog is
  # there, :too_short when no word is long enough.
  def search(query)
    return :preparing unless ready?

    language = query[/(?:\A|\s)lang:([a-z]{2,3})\b/i, 1]&.downcase
    words = query.sub(/(?:\A|\s)lang:\S*/i, ' ').scan(/[\p{L}\p{N}]+/).select { |w| w.length >= MIN_WORD }
    return :too_short if words.empty?

    BookModel.search(words.first(MAX_WORDS), language: language, limit: SEARCH_LIMIT)
  end

  # The catalog's record of book +id+, the Classics entry when the catalog
  # does not have it, or nil.
  def book(id) = BookModel.book(id) || @classics.find(id.to_i)

  def reads(book) = ReadModel.count_of(book.id)

  # The +n+ books most read on this board as [book, reads].
  def most_read(n = 15)
    top = ReadModel.top(n)
    by_id = BookModel.books(top.map(&:first)).to_h { |b| [b.id, b] }
    top.filter_map { |id, count| (b = by_id[id] || @classics.find(id)) && [b, count] }
  end

  def stale?
    at = BookModel.imported_at
    at.nil? || Time.now - at > @ttl
  end

  # Downloads and imports the catalog when it is stale (or when +force+).
  # Returns :fresh, :busy (an import is running) or :updated. Raises when
  # the mirror or the import fails (Rubbs::Common::Web::HTTP::Error, SystemCallError,
  # CSV or database errors); the old catalog stays then.
  def refresh(force: false)
    return :fresh unless force || stale?
    return :busy unless @lock.synchronize { !@importing && (@importing = true) }

    begin
      import
    ensure
      @lock.synchronize { @importing = false }
    end
  end

  private

  def import
    started = Time.now
    @gutenberg.download_catalog(@catalog_file)
    n = CatalogBuilder.new.build(@catalog_file)
    Rubbs.log('catalog', format('imported, %<n>d books in %<s>.1f s', n: n, s: Time.now - started))
    GC.start
    :updated
  ensure
    FileUtils.rm_f(@catalog_file)
  end
end
