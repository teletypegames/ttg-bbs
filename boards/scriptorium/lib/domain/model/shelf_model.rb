# frozen_string_literal: true

# A shelf of books: a Project Gutenberg bookshelf of the catalog (+kind+
# :bookshelf, +id+ its row id) or the board's own curated one (+kind+
# :classics). +count+ is how many books stand on it.
ShelfModel = Data.define(:id, :kind, :name, :count) do
  def classics? = kind == :classics

  # The name without the "Category: " prefix of the newer bookshelves.
  def label = name.delete_prefix('Category: ')

  def category? = name.start_with?('Category: ')
end
