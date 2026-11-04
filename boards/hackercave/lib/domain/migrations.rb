# frozen_string_literal: true

# The schemas of the board's four SQLite files, one step per version
# (BBS::Database.migrate, counted in PRAGMA user_version).

# data/hackercave.sqlite3: the reads (ReadModel).
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE reads (id INTEGER PRIMARY KEY, rfc INTEGER NOT NULL, at TEXT NOT NULL);
  CREATE INDEX reads_rfc ON reads (rfc);
SQL

# The schemas of the two databases that are built whole, not migrated: a
# build drops the tables and makes them anew (Schema::Index.create,
# Schema::Jargon.create), in the transaction it fills them in.
module Schema
  # The tables of the index of the RFC Editor (data/index.sqlite3): RfcModel,
  # RelationModel, SeriesModel, ErratumModel, and the full-text index of the
  # titles, authors, keywords and abstracts (FTS5; a search column for LIKE
  # where the SQLite has no FTS5), built by IndexBuilder (RfcModel.rebuild).
  module Index
    TABLES = [
      'CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, authors TEXT, date TEXT, year INTEGER, pages INTEGER, ' \
      'status TEXT, pub_status TEXT, stream TEXT, area TEXT, wg TEXT, abstract TEXT, keywords TEXT, formats TEXT, ' \
      'issued INTEGER, search TEXT)',
      'CREATE INDEX rfcs_status ON rfcs (status, number)',
      'CREATE INDEX rfcs_year ON rfcs (year, number)',
      'CREATE TABLE relations (rfc INTEGER, kind TEXT, target INTEGER)',
      'CREATE INDEX relations_rfc ON relations (rfc)',
      'CREATE TABLE series (series TEXT, number INTEGER, rfc INTEGER)',
      'CREATE INDEX series_kind ON series (series, number)',
      'CREATE INDEX series_rfc ON series (rfc)',
      'CREATE TABLE errata (id INTEGER PRIMARY KEY, rfc INTEGER, status TEXT, type TEXT, section TEXT, orig_text TEXT, ' \
      'correct_text TEXT, notes TEXT, submitted TEXT)',
      'CREATE INDEX errata_rfc ON errata (rfc)'
    ].freeze
    FTS = "CREATE VIRTUAL TABLE rfcs_fts USING fts5(title, authors, keywords, abstract, content='rfcs', " \
          "content_rowid='number', tokenize='unicode61 remove_diacritics 2')"
    # The tables to drop, the full-text index before its content.
    DROP = %i[rfcs_fts errata series relations rfcs].freeze

    # Whether +db+ has the index of this board: the tables, the formats of
    # the RFCs and the errata (an older board's had not).
    def self.current?(db)
      (%w[rfcs relations series errata] - db[:sqlite_master].where(type: 'table').select_map(:name)).empty? &&
        db.fetch('SELECT name FROM pragma_table_info(?)', 'rfcs').select_map(:name).include?('formats')
    end

    # Drops the tables of +db+ and makes them anew, empty. True when the
    # SQLite has FTS5.
    def self.create(db)
      DROP.each { |table| db.drop_table?(table) }
      TABLES.each { |sql| db.run(sql) }
      fts(db)
    end

    # Makes the full-text index; false when the SQLite has no FTS5.
    def self.fts(db)
      db.run(FTS)
      true
    rescue Sequel::DatabaseError
      false
    end
  end

  # The tables of the Jargon File (data/jargon.sqlite3): JargonMetaModel,
  # JargonEntryModel, JargonSectionModel and the full-text index of the
  # headwords and the text, built from the File (JargonEntryModel.rebuild).
  module Jargon
    TABLES = [
      'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)',
      'CREATE TABLE entries (id INTEGER PRIMARY KEY, headword TEXT, key TEXT, pron TEXT, body TEXT)',
      'CREATE INDEX entries_key ON entries (key)',
      'CREATE TABLE sections (id INTEGER PRIMARY KEY, title TEXT, body TEXT)',
      "CREATE VIRTUAL TABLE entries_fts USING fts5(headword, body, tokenize='unicode61 remove_diacritics 2')"
    ].freeze
    DROP = %i[entries_fts sections entries meta].freeze

    def self.current?(db)
      (%w[meta entries sections entries_fts] - db[:sqlite_master].where(type: 'table').select_map(:name)).empty?
    end

    # Drops the tables of +db+ and makes them anew, empty.
    def self.create(db)
      DROP.each { |table| db.drop_table?(table) }
      TABLES.each { |sql| db.run(sql) }
    end
  end
end

# data/index.sqlite3: the empty tables of a new file, so the models bind,
# and an index of an older board emptied, so the next refresh imports it
# anew.
INDEX_MIGRATIONS = [->(db) { Schema::Index.create(db) unless Schema::Index.current?(db) }].freeze

# data/fulltext.sqlite3 (DocModel): a contentless FTS5 table, so only the
# index is stored, not the text a second time, and the docs table with the
# size and mtime each text was indexed at.
FULLTEXT_MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE IF NOT EXISTS docs (number INTEGER PRIMARY KEY, size INTEGER, mtime INTEGER);
  CREATE VIRTUAL TABLE IF NOT EXISTS text_fts USING fts5(body, content='', contentless_delete=1,
                                                         tokenize='unicode61 remove_diacritics 2');
SQL

# data/jargon.sqlite3: the empty tables of a new file, so the models bind.
JARGON_MIGRATIONS = [->(db) { Schema::Jargon.create(db) unless Schema::Jargon.current?(db) }].freeze
