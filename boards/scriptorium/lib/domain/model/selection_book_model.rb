# frozen_string_literal: true

# A book on a Project Gutenberg bookshelf (a row of the selection_books table of
# data/catalog.sqlite3).
class SelectionBookModel < Rubbs::Common::Storage::Model
  table :selection_books, database: :catalog

  # The first +limit+ books of bookshelf +selection_id+, lowest numbers first:
  # the oldest ebooks of Project Gutenberg are its best known ones.
  def self.books_on(selection_id, limit: 200)
    BookModel.guard([]) do
      BookModel.select(*BookModel::COLUMNS.map { |c| Sequel[:books][c] }).join(:selection_books, book_id: :id)
        .where(Sequel[:selection_books][:selection_id] => selection_id).order(Sequel[:books][:id]).limit(limit).all
    end
  end
end
