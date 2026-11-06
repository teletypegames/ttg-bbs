# frozen_string_literal: true

# A category of the blog, from config/categories.yml. A post names its
# category by +id+; a post whose category left the file shows its bare id.
CategoryModel = Data.define(:id, :name, :about) do
  def self.from_entry(entry) = new(id: entry.fetch('id').to_s, name: entry.fetch('name').to_s, about: entry['about'].to_s)

  # The stand-in for an id the file no longer lists.
  def self.unknown(id) = new(id: id, name: id, about: '')
end
