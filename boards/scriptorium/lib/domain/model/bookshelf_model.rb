# frozen_string_literal: true

# A Project Gutenberg bookshelf of the catalog (a row of the bookshelves table
# of data/catalog.sqlite3): its name and how many books stand on it.
class BookshelfModel < Rubbs::Common::Storage::Model
  table :bookshelves, database: :catalog

  # The bookshelves as SelectionModel, the older named ones first, then the
  # categories.
  def self.all_selections
    rows = BookModel.guard([]) { order(Sequel.like(:name, 'Category: %'), :name).all }
    rows.map { |s| SelectionModel.new(id: s.id, kind: :bookshelf, name: s.name, count: s.books) }
  end

  # Keeps that book +rows+ ([name, book_id]) stand on the bookshelves of
  # these names, in the build's MEMBERSHIPS.
  def self.add_members(rows) = db[:memberships].import(%i[name book_id], rows)

  # Makes the bookshelves of the build's MEMBERSHIPS, with their books
  # (SelectionBookModel), and drops it.
  def self.gather
    members = db[:memberships]
    dataset.insert(%i[name books], members.group_and_count(:name))
    on_bookshelves = members.join(:bookshelves, name: :name).select(Sequel[:bookshelves][:id], Sequel[:memberships][:book_id])
    SelectionBookModel.dataset.insert(%i[selection_id book_id], on_bookshelves)
    db.drop_table(:memberships)
  end
end
