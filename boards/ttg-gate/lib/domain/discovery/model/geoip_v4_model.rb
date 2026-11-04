# frozen_string_literal: true

module Discovery
  # An IPv4 range of the country lookup file (GeoipRepository): its first
  # and last address as numbers and its country code.
  class GeoipV4Model < BBS::Model
    table :v4, database: :geoip

    # The country code of the range +address+ (a number) is in, or nil.
    def self.country(address)
      row = where { start <= address }.reverse(:start).select(:stop, :cc).naked.first
      row[:cc] if row && row[:stop] >= address
    end

    # Writes +ranges+ ([start, stop, cc] each) into the lookup file being
    # made, +db+; a range of the same start replaces the one there.
    def self.add(db, ranges) = db[:v4].insert_conflict(:replace).import(%i[start stop cc], ranges)
  end
end
