# frozen_string_literal: true

require 'csv'
require 'zlib'

# Builds the catalog (BookModel, BookshelfModel, ShelfBookModel) anew from
# Project Gutenberg's pg_catalog.csv.gz: its Text rows as books, the
# bookshelves they stand on, and the full-text index of titles and authors
# (FTS5; a search column for LIKE where the SQLite has no FTS5). The rows go
# to the models in slices of SLICE.
class CatalogBuilder
  SLICE = 500

  # Builds the catalog from +csv_gz+ in place of the old one
  # (BookModel.rebuild: in one transaction, so callers read the old one
  # meanwhile). Returns the number of books. Raises what reading the file
  # raises; the old catalog stays then.
  def build(csv_gz)
    BookModel.rebuild do |fts|
      books   = []
      members = []
      n = 0
      each_book(csv_gz) do |values|
        books << [*values, fts ? nil : "#{values[1]} #{values[2]}".downcase]
        values[6].split('; ').each { |s| members << [s.strip, values[0]] unless s.strip.empty? }
        n += 1
        flush(books, members) if books.size >= SLICE
      end
      flush(books, members)
      n
    end
  end

  private

  # Writes the books and memberships kept.
  def flush(books, members)
    BookModel.insert_rows(books) unless books.empty?
    BookshelfModel.add_members(members) unless members.empty?
    books.clear
    members.clear
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
end
