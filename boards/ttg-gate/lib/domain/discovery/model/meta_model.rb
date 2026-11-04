# frozen_string_literal: true

module Discovery
  # A value of the catalog by its key: when the first import ran
  # (started_at), the last one, and the running totals of the pruned dial
  # refusals.
  class MetaModel < BBS::Model
    table :meta, database: :discovery

    # The value of +key+ (a String), or nil.
    def self.value(key) = where(key: key).get(:value)

    # Sets +key+ to +value+ (as text).
    def self.store(key, value)
      dataset.insert_conflict(target: :key, update: { value: Sequel[:excluded][:value] }).insert(key: key, value: value.to_s)
    end

    # Adds +amount+ to the number kept under +key+ (made when missing).
    def self.add(key, amount)
      db[<<~SQL, key, amount.to_s].insert
        INSERT INTO meta (key, value) VALUES (?, ?)
        ON CONFLICT (key) DO UPDATE SET value = CAST(value AS INTEGER) + CAST(excluded.value AS INTEGER)
      SQL
    end

    # The rows whose key starts with +prefix+: [key, value] pairs.
    def self.prefixed(prefix) = where(Sequel.like(:key, "#{prefix}%")).select_map(%i[key value])
  end
end
