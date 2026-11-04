# frozen_string_literal: true

# The schema of the tips, one step per version (BBS::Database.migrate).
# Step 1 is the schema the board created before it had versions, written IF
# NOT EXISTS: a file of that time (user_version 0, the table already there)
# only gets its version, and keeps its rows.
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
