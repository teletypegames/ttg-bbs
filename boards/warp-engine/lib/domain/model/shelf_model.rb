# frozen_string_literal: true

# A shelf of the archive, from config/shelves.yml: a folder with an
# INDEX.TXT that lists its titles.
ShelfModel = Data.define(:id, :name, :path, :about) do
  def self.from_entry(entry)
    new(id: entry.fetch('id').to_s, name: entry.fetch('name').to_s,
        path: "/#{entry.fetch('path').to_s.delete_prefix('/').delete_suffix('/')}", about: entry['about'].to_s)
  end
end
