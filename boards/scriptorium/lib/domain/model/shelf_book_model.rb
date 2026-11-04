# frozen_string_literal: true

# A book on a Project Gutenberg bookshelf (a row of the shelf_books table of
# data/catalog.sqlite3).
class ShelfBookModel < BBS::Model
  table :shelf_books, database: :catalog

  # The first +limit+ books of bookshelf +shelf_id+, lowest numbers first:
  # the oldest ebooks of Project Gutenberg are its best known ones.
  def self.books_on(shelf_id, limit: 200)
    BookModel.guard([]) do
      BookModel.select(*BookModel::COLUMNS.map { |c| Sequel[:books][c] }).join(:shelf_books, book_id: :id)
               .where(Sequel[:shelf_books][:shelf_id] => shelf_id).order(Sequel[:books][:id]).limit(limit).all
    end
  end
end
