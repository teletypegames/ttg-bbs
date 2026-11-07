# frozen_string_literal: true

# The schemas of the board's SQLite files, each step counted in
# PRAGMA user_version (Rubbs::Common::Storage::Database.migrate).
#
# Global Discovery's catalog (data/discovery.sqlite3) was made before it was
# versioned: its tables were made on every open (CREATE ... IF NOT EXISTS)
# and the columns added later were added when missing. Both are its first
# two steps as they were, so a catalog of version 0 goes through them
# without a change and one made new ends the same.
DISCOVERY_SCHEMA = <<~SQL
  CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
  );
  CREATE TABLE IF NOT EXISTS sources (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    url             TEXT NOT NULL,
    format          TEXT NOT NULL,
    licence         TEXT,
    attribution     TEXT,
    last_fetch_at   INTEGER,
    last_parse_at   INTEGER,
    record_count    INTEGER,
    last_error      TEXT,
    last_error_at   INTEGER,
    refused_at      INTEGER
  );
  CREATE TABLE IF NOT EXISTS boards (
    id            INTEGER PRIMARY KEY,
    host          TEXT NOT NULL,
    port          INTEGER NOT NULL,
    name          TEXT,
    sysop         TEXT,
    location      TEXT,
    software      TEXT,
    since         INTEGER,
    ftn_address   TEXT,
    provenance    TEXT NOT NULL DEFAULT '{}',
    first_seen_at INTEGER NOT NULL,
    last_seen_at  INTEGER NOT NULL,
    delisted      INTEGER NOT NULL DEFAULT 0,
    delisted_at   INTEGER,
    alias_of      INTEGER REFERENCES boards(id),
    optout        TEXT,
    UNIQUE (host, port)
  );
  CREATE TABLE IF NOT EXISTS board_sources (
    board_id      INTEGER NOT NULL REFERENCES boards(id),
    source_id     TEXT NOT NULL,
    fields        TEXT NOT NULL,
    active        INTEGER NOT NULL DEFAULT 1,
    first_seen_at INTEGER NOT NULL,
    last_seen_at  INTEGER NOT NULL,
    PRIMARY KEY (board_id, source_id)
  );
  CREATE INDEX IF NOT EXISTS board_sources_source ON board_sources (source_id, active);
  CREATE TABLE IF NOT EXISTS probes (
    id          INTEGER PRIMARY KEY,
    board_id    INTEGER NOT NULL REFERENCES boards(id),
    at          INTEGER NOT NULL,
    kind        TEXT NOT NULL,
    result      TEXT NOT NULL,
    latency_ms  INTEGER,
    ip          TEXT,
    banner      BLOB,
    banner_hash TEXT,
    options     TEXT
  );
  CREATE INDEX IF NOT EXISTS probes_board_at ON probes (board_id, at);
  CREATE INDEX IF NOT EXISTS probes_at ON probes (at);
  CREATE TABLE IF NOT EXISTS board_state (
    board_id          INTEGER PRIMARY KEY REFERENCES boards(id),
    state             TEXT NOT NULL DEFAULT 'unknown',
    state_since       INTEGER,
    success_rate_7d   REAL,
    failures          INTEGER NOT NULL DEFAULT 0,
    first_probe_at    INTEGER,
    last_probe_at     INTEGER,
    last_result       TEXT,
    last_success_at   INTEGER,
    next_probe_at     INTEGER,
    archived          INTEGER NOT NULL DEFAULT 0,
    ip                TEXT,
    country           TEXT,
    latency_ms        INTEGER,
    encoding          TEXT,
    software_id       TEXT,
    software          TEXT,
    options           TEXT,
    banner            BLOB,
    banner_hash       TEXT,
    banner_at         INTEGER,
    banner_changed_at INTEGER
  );
  CREATE INDEX IF NOT EXISTS board_state_due ON board_state (archived, next_probe_at);
  CREATE TABLE IF NOT EXISTS tags (
    board_id INTEGER NOT NULL REFERENCES boards(id),
    tag      TEXT NOT NULL,
    PRIMARY KEY (board_id, tag)
  );
  CREATE INDEX IF NOT EXISTS tags_tag ON tags (tag);
  CREATE VIRTUAL TABLE IF NOT EXISTS boards_fts USING fts5 (name, sysop, location, software, host);
  CREATE TABLE IF NOT EXISTS dial_refusals (
    id       INTEGER PRIMARY KEY,
    at       INTEGER NOT NULL,
    reason   TEXT NOT NULL,
    board_id INTEGER,
    face     TEXT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS dial_refusals_at ON dial_refusals (at);
  CREATE TABLE IF NOT EXISTS dials (
    id       INTEGER PRIMARY KEY,
    at       INTEGER NOT NULL,
    board_id INTEGER NOT NULL,
    face     TEXT NOT NULL,
    result   TEXT NOT NULL,
    seconds  INTEGER NOT NULL,
    bytes    INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS dials_at ON dials (at);
SQL

# The columns added after the first release: the whole call's time and
# the banner's size of a probe (the banner itself is not kept for long);
# the hardware and website a list (the CBBS Outpost) gives a board; what
# the C64-style call of a board found, and the reading window it had.
DISCOVERY_ADDED = {
  'probes'      => { 'duration_ms' => 'INTEGER', 'banner_bytes' => 'INTEGER' },
  'boards'      => { 'hardware' => 'TEXT', 'website' => 'TEXT' },
  'board_state' => {
    'c64_probe_at'    => 'INTEGER',
    'c64_result'      => 'TEXT',
    'c64_encoding'    => 'TEXT',
    'c64_banner'      => 'BLOB',
    'c64_banner_hash' => 'TEXT',
    'c64_banner_at'   => 'INTEGER',
    'c64_window'      => 'INTEGER'
  }
}.freeze

DISCOVERY_MIGRATIONS = [
  DISCOVERY_SCHEMA,
  lambda do |db|
    DISCOVERY_ADDED.each do |table, added|
      columns = db.fetch("PRAGMA table_info(#{table})").map { |column| column[:name] }
      added.each do |name, type|
        db.run("ALTER TABLE #{table} ADD COLUMN #{name} #{type}") unless columns.include?(name)
      end
    end
  end
].freeze

# The country lookup file of DB-IP's ranges (data/geoip/), made new each
# month by GeoipRepository.
GEOIP_MIGRATIONS = [
  <<~SQL
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
    CREATE TABLE v4 (start INTEGER PRIMARY KEY, stop INTEGER NOT NULL, cc TEXT NOT NULL);
    CREATE TABLE v6 (start BLOB PRIMARY KEY, stop BLOB NOT NULL, cc TEXT NOT NULL) WITHOUT ROWID;
  SQL
].freeze

# The Today tab's cache (data/herald.sqlite3, HeraldModel): one row a web
# source of Herald, its last payload and when it came.
HERALD_MIGRATIONS = [
  <<~SQL
    CREATE TABLE herald (
      source     TEXT PRIMARY KEY,
      fetched_at INTEGER NOT NULL,
      payload    TEXT NOT NULL
    );
  SQL
].freeze
