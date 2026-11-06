# frozen_string_literal: true

# The schema of the board's database, one step per version
# (Rubbs::Common::Storage::Database.migrate): the admins' inbox of before the
# network's feedback, and when each message was handed over to it.
MIGRATIONS = [<<~SQL, <<~SQL].freeze
  CREATE TABLE messages (
    id     INTEGER PRIMARY KEY,
    kind   TEXT NOT NULL,
    at     TEXT NOT NULL,
    sender TEXT,
    name   TEXT,
    url    TEXT,
    text   TEXT
  )
SQL
  ALTER TABLE messages ADD COLUMN exported_at TEXT
SQL
