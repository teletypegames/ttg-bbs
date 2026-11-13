# frozen_string_literal: true

# The schema of the callers' data, one step per version (Rubbs::Common::Storage::Database.migrate):
# the machines an account marked, the memories callers wrote, and how often each machine's page
# was opened.
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE marks (
    account_id TEXT NOT NULL,
    handle     TEXT NOT NULL,
    machine_id TEXT NOT NULL,
    kind       TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (account_id, machine_id, kind)
  );
  CREATE INDEX marks_machine ON marks (machine_id, kind);
  CREATE TABLE memories (
    id         INTEGER PRIMARY KEY,
    account_id TEXT NOT NULL,
    handle     TEXT NOT NULL,
    machine_id TEXT NOT NULL,
    text       TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'pending',
    created_at TEXT NOT NULL
  );
  CREATE INDEX memories_machine_status ON memories (machine_id, status);
  CREATE TABLE views (
    machine_id TEXT PRIMARY KEY,
    count      INTEGER NOT NULL DEFAULT 0,
    last_at    TEXT NOT NULL
  );
SQL
