# frozen_string_literal: true

module Discovery
  # A dial the Gate refused: when, why, which board, which face; nothing of
  # the caller (DialHistoryService).
  class DialRefusalModel < Rubbs::Common::Storage::Model
    table :dial_refusals, database: :discovery

    # The refusals before +time+ a reason and face: { [reason, face] => n }.
    def self.counts_before(time) = where { at < time }.group_and_count(:reason, :face).to_hash(%i[reason face], :count)

    # Every refusal a reason and face: { [reason, face] => n }.
    def self.counts = group_and_count(:reason, :face).to_hash(%i[reason face], :count)

    # The refusals since +from+ a reason: { reason => n }.
    def self.reasons_since(from) = where { at >= from }.group_and_count(:reason).as_hash(:reason, :count)

    # Drops the refusals before +time+.
    def self.drop_before(time) = where { at < time }.delete
  end
end
