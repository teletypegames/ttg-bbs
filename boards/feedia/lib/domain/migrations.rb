# frozen_string_literal: true

# The schema of the board's database, one step per version
# (Rubbs::Common::Storage::Database.migrate): the admins' inbox.
MIGRATIONS = [<<~SQL].freeze
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
