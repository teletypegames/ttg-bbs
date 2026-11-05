# frozen_string_literal: true

module Discovery
  # A value of the country lookup file (GeoipRepository): the month of DB-IP
  # it was made of.
  class GeoipMetaModel < Rubbs::Common::Storage::Model
    table :meta, database: :geoip

    # The month of the lookup file in use ("2026-11"), or nil.
    def self.month = where(key: 'month').get(:value)

    # Writes +month+ into the lookup file being made, +db+.
    def self.made_of(db, month) = db[:meta].insert(key: 'month', value: month)
  end
end
