# frozen_string_literal: true

# What data/jargon.sqlite3 knows of itself (the meta table): +source+, the
# SHA-256 of the file it was built from.
class JargonMetaModel < BBS::Model
  table :meta, database: :jargon

  # The digest of the file the database was built from, or nil.
  def self.source = JargonEntryModel.guard(nil) { where(key: 'source').get(:value) }

  def self.source=(digest)
    insert(key: 'source', value: digest)
  end
end
