# frozen_string_literal: true

module Discovery
  # A dial of the Gate that went: its result, the seconds it was connected
  # and the bytes the board sent through the Gate (DialHistoryService).
  class DialModel < BBS::Model
    table :dials, database: :discovery

    # The dials since +from+: [how many, their seconds on the line, the
    # bytes relayed].
    def self.traffic_since(from)
      row = where { at >= from }.select(
        Sequel.function(:count).*.as(:n),
        Sequel.function(:sum, :seconds).as(:s),
        Sequel.function(:sum, :bytes).as(:b)
      ).naked.first
      [row[:n].to_i, row[:s].to_i, row[:b].to_i]
    end

    # Drops the dials before +time+.
    def self.drop_before(time) = where { at < time }.delete
  end
end
