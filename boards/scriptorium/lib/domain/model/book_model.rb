# frozen_string_literal: true

# One ebook of the catalog: a row of the books table of data/catalog.sqlite3
# (CatalogSchema), or an entry of the curated shelf while the catalog is not
# there yet (::stub). +authors+ and +bookshelves+ are as the catalog gives
# them, "; " between the names.
#
# The class methods are the catalog's queries: a book, the books of a list,
# the search, and its rebuild. Until the first import the table is empty and
# they find nothing.
class BookModel < BBS::Model
  table :books, database: :catalog

  # The columns a BookModel is read with.
  COLUMNS = %i[id title authors language issued subjects bookshelves].freeze
  # The columns a row is written with (CatalogBuilder), in the table's order.
  ROW = %i[id title authors language issued subjects bookshelves search].freeze
  TEXTS = %i[title authors language issued subjects bookshelves].freeze

  TEXTS.each { |column| define_method(column) { self[column].to_s } }

  def id = self[:id]

  # A book known only by its number, title and author (config/classics.yml).
  def self.stub(id:, title:, author: '', language: 'en')
    load(id: id, title: title, authors: author, language: language, issued: '', subjects: '', bookshelves: '')
  end

  # Whether the catalog was imported: it has books.
  def self.ready? = guard(false) { !dataset.empty? }

  # When the catalog was last imported (its file last written), or nil.
  def self.imported_at
    path = db.opts[:database].to_s
    ready? && File.exist?(path) ? File.mtime(path) : nil
  end

  # The number of books, counted once a catalog.
  def self.total
    totals.fetch(db) do
      n = guard(0) { count }
      n.positive? ? (totals[db] = n) : n
    end
  end

  def self.book(id)
    guard(nil) { select(*COLUMNS).where(id: Integer(id)).first }
  rescue ArgumentError, TypeError
    nil
  end

  # The books of +ids+ in the order given; the ones not in the catalog are
  # left out.
  def self.books(ids)
    ids = ids.map(&:to_i)
    return [] if ids.empty?

    by_id = guard([]) { select(*COLUMNS).where(id: ids).all }.to_h { |b| [b.id, b] }
    ids.filter_map { |id| by_id[id] }
  end

  # At most +limit+ books whose title or author has every word of +words+
  # (as a word prefix), in +language+ when one is given.
  def self.search(words, language: nil, limit: 100)
    return [] if words.empty?

    found = select(*COLUMNS.map { |c| Sequel[:books][c] })
    found = found.exclude(Sequel.function(:instr, Sequel[:books][:language], language) => 0) if language
    guard([]) { (fts? ? match(found, words) : like(found, words)).limit(limit).all }
  end

  # Empties the catalog and runs the block, which fills it (CatalogBuilder),
  # given whether the full-text index is FTS5; then the bookshelves are
  # gathered (BookshelfModel.gather) and the full-text index built. All in
  # one transaction: callers read the old catalog meanwhile, and it stays
  # when the block raises. Returns the block's value.
  def self.rebuild
    value = db.transaction do
      fts = CatalogSchema.create(db)
      db.run(CatalogSchema::MEMBERSHIPS)
      yield(fts).tap { finish(fts) }
    end
    totals.delete(db)
    db.run('PRAGMA wal_checkpoint(TRUNCATE)')
    value
  end

  # Writes +rows+ (values in the order of ROW).
  def self.insert_rows(rows) = dataset.import(ROW, rows)

  # The value of the block, or +fallback+ when the database fails (logged).
  def self.guard(fallback)
    yield
  rescue Sequel::DatabaseError => e
    BBS.log('catalog', "#{e.class}: #{e.message}")
    fallback
  end

  def self.totals = @totals ||= {}

  def self.finish(fts)
    BookshelfModel.gather
    CatalogSchema.index(db)
    db.run("INSERT INTO books_fts (books_fts) VALUES ('rebuild')") if fts
  end

  # Whether the full-text index is FTS5.
  def self.fts? = !db[:sqlite_master].where(name: 'books_fts').empty?

  # The full-text search of +found+: every word a prefix, best matches first.
  def self.match(found, words)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    found.join(:books_fts, rowid: :id).where(Sequel.lit('books_fts MATCH ?', terms))
         .order(Sequel.function(:bm25, :books_fts, 10.0, 5.0), Sequel[:books][:id])
  end

  # The search of an SQLite without FTS5: every word somewhere.
  def self.like(found, words)
    words.reduce(found) { |ds, w| ds.where(Sequel.like(Sequel[:books][:search], "%#{w.downcase}%")) }.order(Sequel[:books][:id])
  end

  private_class_method :totals, :finish, :fts?, :match, :like

  # The first line of the title: the catalog puts a subtitle on a line of its own.
  def short_title = title.lines.first.to_s.strip

  # The subtitle lines, joined; empty when there is none.
  def subtitle = title.lines.drop(1).map(&:strip).reject(&:empty?).join(' ')

  # The authors as they are read: "Mary Wollstonecraft Shelley", without the
  # years and the role ("[Editor]").
  def author_names = authors.split('; ').map { |a| self.class.person(a) }.reject(&:empty?)

  # The first author, or "Anonymous".
  def author = author_names.first || 'Anonymous'

  def subject_list = subjects.split('; ').reject(&:empty?)

  # The bookshelves of the book, without the "Category: " prefix.
  def shelf_names = bookshelves.split('; ').reject(&:empty?).map { |s| s.delete_prefix('Category: ') }

  def url = "gutenberg.org/ebooks/#{id}"

  # The book's page on Project Gutenberg, the address of its QR code.
  def link = "https://www.#{url}"

  # "Shelley, Mary Wollstonecraft, 1797-1851 [Editor]" → "Mary Wollstonecraft Shelley".
  def self.person(name)
    name = name.sub(/\s*\[[^\]]*\]\s*\z/, '').sub(/,\s*(?:active\s+)?(?:\d|BCE|-|\?)[^,]*\z/, '').strip
    last, first = name.split(', ', 2)
    return name if first.nil? || first.include?(',')

    first = first.sub(/\s*\(.*\)\z/, '')
    "#{first} #{last}"
  end
end
