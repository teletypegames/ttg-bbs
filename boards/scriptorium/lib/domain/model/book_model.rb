# frozen_string_literal: true

# One ebook of the catalog: a row of the books table (or an entry of the
# curated shelf while the catalog is not there yet). +authors+ and
# +bookshelves+ are as the catalog gives them, "; " between the names.
BookModel = Data.define(:id, :title, :authors, :language, :issued, :subjects, :bookshelves) do
  # The book of a catalog row, a Hash with the column names as String keys.
  def self.from_row(row)
    new(id: row['id'], title: row['title'].to_s, authors: row['authors'].to_s, language: row['language'].to_s,
        issued: row['issued'].to_s, subjects: row['subjects'].to_s, bookshelves: row['bookshelves'].to_s)
  end

  # A book known only by its number, title and author (config/classics.yml).
  def self.stub(id:, title:, author: '', language: 'en')
    new(id: id, title: title, authors: author, language: language, issued: '', subjects: '', bookshelves: '')
  end

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
