# frozen_string_literal: true

require 'fileutils'
require 'monitor'
require 'sqlite3'

module Discovery
  # The SQLite file of Global Discovery (data/discovery.sqlite3) and its one
  # connection, behind a mutex. WAL mode: the importer and the prober write,
  # the Gate reads, and nobody waits for a whole import. The schema is created
  # on open (CREATE … IF NOT EXISTS); a new column needs a migration step here.
  class Database
    SCHEMA = <<~SQL
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
    ADDED = {
      'probes'      => { 'duration_ms' => 'INTEGER', 'banner_bytes' => 'INTEGER' },
      'boards'      => { 'hardware' => 'TEXT', 'website' => 'TEXT' },
      'board_state' => { 'c64_probe_at' => 'INTEGER', 'c64_result' => 'TEXT', 'c64_encoding' => 'TEXT',
                         'c64_banner' => 'BLOB', 'c64_banner_hash' => 'TEXT', 'c64_banner_at' => 'INTEGER',
                         'c64_window' => 'INTEGER' }
    }.freeze

    attr_reader :path

    def initialize(path)
      @path = path
      FileUtils.mkdir_p(File.dirname(path))
      @db = SQLite3::Database.new(path)
      @db.results_as_hash = true
      @db.busy_timeout = 10_000
      @db.execute('PRAGMA journal_mode = WAL')
      @db.execute('PRAGMA foreign_keys = ON')
      @db.execute_batch(SCHEMA)
      migrate
      @mutex = Monitor.new
    end

    # The rows of a query, as hashes.
    def query(sql, *args) = @mutex.synchronize { @db.execute(sql, args) }

    # The first row of a query, or nil.
    def first(sql, *) = query(sql, *).first

    # The first column of the first row, or nil.
    def value(sql, *) = first(sql, *)&.values&.first

    # The number of rows a statement changed.
    def change(sql, *args)
      @mutex.synchronize do
        @db.execute(sql, args)
        @db.changes
      end
    end

    # The rowid of the row a statement inserted.
    def insert(sql, *args)
      @mutex.synchronize do
        @db.execute(sql, args)
        @db.last_insert_row_id
      end
    end

    # The block in one transaction; the methods above work inside it.
    def transaction(&)
      @mutex.synchronize do
        return yield if @db.transaction_active?

        @db.transaction(:immediate, &)
      end
    end

    def close = @mutex.synchronize { @db.close }

    private

    def migrate
      ADDED.each do |table, added|
        columns = @db.execute("PRAGMA table_info(#{table})").map { |c| c['name'] }
        added.each do |name, type|
          @db.execute("ALTER TABLE #{table} ADD COLUMN #{name} #{type}") unless columns.include?(name)
        end
      end
    end
  end
end
