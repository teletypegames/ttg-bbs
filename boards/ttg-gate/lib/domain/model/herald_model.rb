# frozen_string_literal: true

# A row of the Today tab's cache (Herald::Store): what a source fetched last
# (+payload+, JSON) and when (+fetched_at+, epoch seconds).
class HeraldModel < Rubbs::Common::Storage::Model
  table :herald, database: :herald

  # Keeps +payload+ (a JSON String) as +source+'s, fetched +at+.
  def self.put(source, payload, at)
    dataset.insert_conflict(target: :source, update: { payload: payload, fetched_at: at })
      .insert(source: source, payload: payload, fetched_at: at)
  end

  # The row of +source+ as a Hash, or +nil+.
  def self.row(source) = where(source: source).first
end
