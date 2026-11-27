# frozen_string_literal: true

require 'time'

# Facts about the catalog itself, a key and a value a row (the meta table of
# data/catalog.sqlite3): imported_at, when the last import finished.
class CatalogMetaModel < Rubbs::Common::Storage::Model
  table :meta, database: :catalog

  # When the catalog was last imported, or nil when it never was.
  def self.imported_at
    value = BookModel.guard(nil) { where(key: 'imported_at').get(:value) }
    value && Time.iso8601(value)
  rescue ArgumentError
    nil
  end

  # Records +at+ as the time of the last import.
  def self.imported!(at = Time.now)
    dataset.insert_conflict(:replace).insert(key: 'imported_at', value: at.utc.iso8601)
  end
end
