# frozen_string_literal: true

require 'time'

# The tips table: what callers sent, pending, approved or rejected. A seed
# tip (config/tips.yml) carries its seed key, so it goes in once.
#
# The schema is migrated with BBS::SQLite#migrate. Step 1 is the schema the
# board created before it had versions, written IF NOT EXISTS: a file of
# that time (user_version 0, the table already there) only gets its
# version, and keeps its rows.
class TipRepository
  MIGRATIONS = [<<~SQL].freeze
    CREATE TABLE IF NOT EXISTS tips (
      id         INTEGER PRIMARY KEY,
      game_id    TEXT NOT NULL,
      handle     TEXT NOT NULL DEFAULT '',
      text       TEXT NOT NULL,
      status     TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      seed       TEXT UNIQUE
    );
    CREATE INDEX IF NOT EXISTS tips_game_status ON tips (game_id, status);
  SQL

  # +db+ is a BBS::SQLite.
  def initialize(db)
    @db = db
    @db.migrate(*MIGRATIONS)
  end

  # The id of the new tip; a seed already in goes in no second time.
  def insert(game_id:, handle:, text:, status: 'pending', seed: nil)
    @db.insert('INSERT OR IGNORE INTO tips (game_id, handle, text, status, created_at, seed) VALUES (?, ?, ?, ?, ?, ?)',
               game_id, handle, text, status, Time.now.utc.iso8601, seed)
  end

  def find(id) = @db.get('SELECT * FROM tips WHERE id = ?', id)&.then { |r| TipModel.from_row(r) }

  def approved(game_id)
    @db.query("SELECT * FROM tips WHERE game_id = ? AND status = 'approved' ORDER BY id", game_id).map do |r|
      TipModel.from_row(r)
    end
  end

  def with_status(status, limit: 100)
    @db.query('SELECT * FROM tips WHERE status = ? ORDER BY id DESC LIMIT ?', status, limit).map { |r| TipModel.from_row(r) }
  end

  def count_approved(game_id)
    @db.get("SELECT COUNT(*) AS n FROM tips WHERE game_id = ? AND status = 'approved'", game_id)['n']
  end

  # The number of approved tips of every game that has one.
  def approved_counts
    @db.query("SELECT game_id, COUNT(*) AS n FROM tips WHERE status = 'approved' GROUP BY game_id")
       .to_h { |r| [r['game_id'], r['n']] }
  end

  # The number of tips changed: 0 when there was no such tip.
  def change_status(id, status) = @db.change('UPDATE tips SET status = ? WHERE id = ?', status, id)
end
