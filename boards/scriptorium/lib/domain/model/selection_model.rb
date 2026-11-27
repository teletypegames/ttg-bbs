# frozen_string_literal: true

# A selection of books: a Project Gutenberg bookshelf of the catalog (+kind+
# :bookshelf, +id+ its row id) or the board's own curated one (+kind+
# :classics). +count+ is how many books stand on it.
SelectionModel = Data.define(:id, :kind, :name, :count) do
  def classics? = kind == :classics

  # The name without the "Category: " prefix of the newer bookshelves.
  def label = name.delete_prefix('Category: ')

  def category? = name.start_with?('Category: ')
end
