# frozen_string_literal: true

# A Project Gutenberg bookshelf of the catalog (a row of the shelves table
# of data/catalog.sqlite3): its name and how many books stand on it.
class BookshelfModel < BBS::Model
  table :shelves, database: :catalog

  # The bookshelves as ShelfModel, the older named ones first, then the
  # categories.
  def self.all_shelves
    shelves = BookModel.guard([]) { order(Sequel.like(:name, 'Category: %'), :name).all }
    shelves.map { |s| ShelfModel.new(id: s.id, kind: :bookshelf, name: s.name, count: s.books) }
  end

  # Keeps that book +rows+ ([name, book_id]) stand on the bookshelves of
  # these names, in the build's MEMBERSHIPS.
  def self.add_members(rows) = db[:memberships].import(%i[name book_id], rows)

  # Makes the bookshelves of the build's MEMBERSHIPS, with their books
  # (ShelfBookModel), and drops it.
  def self.gather
    members = db[:memberships]
    dataset.insert(%i[name books], members.group_and_count(:name))
    on_shelves = members.join(:shelves, name: :name).select(Sequel[:shelves][:id], Sequel[:memberships][:book_id])
    ShelfBookModel.dataset.insert(%i[shelf_id book_id], on_shelves)
    db.drop_table(:memberships)
  end
end
