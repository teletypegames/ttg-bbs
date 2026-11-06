# frozen_string_literal: true

# A text of an RFC (or IEN) in the full-text index (data/fulltext.sqlite3):
# a row of the docs table, with the size and mtime its file had when it was
# indexed, so a sync re-indexes only what changed. The words are in the
# contentless FTS5 table text_fts, under the RFC's number. Written by the
# mirror's thread, read by the callers'.
class DocModel < Rubbs::Common::Storage::Model
  table :docs, database: :fulltext

  # How many texts are indexed.
  def self.indexed = guard(0) { count }

  # The texts indexed, with the size and mtime they had: { 854 => [57_000, 1700000000] }.
  def self.stats = guard({}) { select_map(%i[number size mtime]).to_h { |n, s, m| [n, [s, m]] } }

  # Indexes +body+ as the text of +number+ (replacing what was there), with
  # the +size+ and +mtime+ of its file.
  def self.put(number, body, size:, mtime:)
    guard(nil) do
      db.transaction do
        db[:text_fts].where(rowid: number).delete
        db[:text_fts].insert(rowid: number, body: body)
        dataset.insert_conflict(:replace).insert(number: number, size: size, mtime: mtime)
      end
    end
  end

  # The numbers of at most +limit+ texts that have every word of +words+
  # (as a word prefix), best matches first.
  def self.search(words, limit:)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    guard([]) do
      db[:text_fts].where(Sequel.lit('text_fts MATCH ?', terms)).order(Sequel.function(:bm25, :text_fts))
        .limit(limit).select_map(:rowid)
    end
  end

  # The value of the block, or +fallback+ when the database fails (logged).
  def self.guard(fallback)
    yield
  rescue Sequel::DatabaseError => e
    Rubbs.log('fulltext', "#{e.class}: #{e.message}")
    fallback
  end

  private_class_method :guard
end
