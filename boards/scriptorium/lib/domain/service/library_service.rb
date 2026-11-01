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

  def initialize(catalog:, classics:, reads:, gutenberg:, catalog_file:, ttl:)
    @catalog      = catalog
    @classics     = classics
    @reads        = reads
    @gutenberg    = gutenberg
    @catalog_file = catalog_file
    @ttl          = ttl
    @importing    = false
    @lock         = Mutex.new
  end

  def ready? = @catalog.ready?

  def importing? = @lock.synchronize { @importing }

  # The number of books in the catalog (0 before the first import).
  def count = @catalog.count

  def classics_shelf = ShelfModel.new(id: 0, kind: :classics, name: 'Classics', count: @classics.all.size)

  # The Classics shelf, then the bookshelves of the catalog.
  def shelves = [classics_shelf, *@catalog.shelves]

  # The books of +shelf+: the curated ones in their order (the catalog's
  # records where it has them), or the first SHELF_LIMIT of a bookshelf.
  def books_on(shelf)
    return @catalog.shelf_books(shelf.id, limit: SHELF_LIMIT) unless shelf.classics?

    known = @catalog.books(@classics.all.map(&:id)).to_h { |b| [b.id, b] }
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

    @catalog.search(words.first(MAX_WORDS), language: language, limit: SEARCH_LIMIT)
  end

  # The catalog's record of book +id+, the Classics entry when the catalog
  # does not have it, or nil.
  def book(id) = @catalog.book(id) || @classics.find(id.to_i)

  def reads(book) = @reads.count(book.id)

  # The +n+ books most read on this board as [book, reads].
  def most_read(n = 15)
    top = @reads.top(n)
    by_id = @catalog.books(top.map(&:first)).to_h { |b| [b.id, b] }
    top.filter_map { |id, count| (b = by_id[id] || @classics.find(id)) && [b, count] }
  end

  def stale?
    at = @catalog.imported_at
    at.nil? || Time.now - at > @ttl
  end

  # Downloads and imports the catalog when it is stale (or when +force+).
  # Returns :fresh, :busy (an import is running), :updated or :failed.
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
    return :failed unless @gutenberg.download_catalog(@catalog_file)

    n = @catalog.import(@catalog_file)
    FileUtils.rm_f(@catalog_file)
    return :failed unless n

    warn format('scriptorium-bbs: catalog imported, %<n>d books in %<s>.1f s', n: n, s: Time.now - started)
    GC.start
    :updated
  end
end
