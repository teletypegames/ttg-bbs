# frozen_string_literal: true

# The schema of the board's database, one step per version
# (Rubbs::Common::Storage::Database.migrate): the downloads that went through.
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE downloads (
    id       INTEGER PRIMARY KEY,
    at       TEXT NOT NULL,
    title    TEXT NOT NULL,
    version  TEXT NOT NULL DEFAULT '',
    protocol TEXT NOT NULL
  );
  CREATE INDEX downloads_title ON downloads (title);
SQL
