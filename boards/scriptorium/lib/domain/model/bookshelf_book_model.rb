# frozen_string_literal: true

# A book on a Project Gutenberg bookshelf (a row of the bookshelf_books table of
# data/catalog.sqlite3).
class BookshelfBookModel < Rubbs::Common::Storage::Model
  table :bookshelf_books, database: :catalog

  # The first +limit+ books of bookshelf +bookshelf_id+, lowest numbers first:
  # the oldest ebooks of Project Gutenberg are its best known ones.
  def self.books_on(bookshelf_id, limit: 200)
    BookModel.guard([]) do
      BookModel.select(*BookModel::COLUMNS.map { |c| Sequel[:books][c] }).join(:bookshelf_books, book_id: :id)
        .where(Sequel[:bookshelf_books][:bookshelf_id] => bookshelf_id).order(Sequel[:books][:id]).limit(limit).all
    end
  end
end
