# frozen_string_literal: true

module Discovery
  # An IPv6 range of the country lookup file (GeoipRepository): its first
  # and last address as 16 bytes and its country code.
  class GeoipV6Model < BBS::Model
    table :v6, database: :geoip

    # The country code of the range +address+ (16 bytes, binary) is in, or
    # nil.
    def self.country(address)
      key = Sequel.blob(address)
      row = where { start <= key }.reverse(:start).select(:stop, :cc).naked.first
      row[:cc] if row && row[:stop].b >= address.b
    end

    # Writes +ranges+ ([start, stop, cc] each, the addresses as 16 bytes)
    # into the lookup file being made, +db+; a range of the same start
    # replaces the one there.
    def self.add(db, ranges)
      rows = ranges.map { |start, stop, cc| [Sequel.blob(start), Sequel.blob(stop), cc] }
      db[:v6].insert_conflict(:replace).import(%i[start stop cc], rows)
    end
  end
end
