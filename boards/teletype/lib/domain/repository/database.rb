# frozen_string_literal: true

require_relative 'legacy_import'

# The board's one SQLite file (data/teletype.sqlite3): its schema, and on
# the first start the CSV files of earlier versions brought in
# (LegacyImport). Every repository that keeps something works on it.
module Database
  SCHEMA = [
    <<~SQL
      CREATE TABLE accounts (
        name_key TEXT PRIMARY KEY, name TEXT NOT NULL, skeleton TEXT NOT NULL,
        salt TEXT NOT NULL, digest TEXT NOT NULL, created_at TEXT NOT NULL);
      CREATE INDEX accounts_skeleton ON accounts (skeleton);

      CREATE TABLE posts (
        id INTEGER PRIMARY KEY, board TEXT NOT NULL, timestamp TEXT NOT NULL,
        username TEXT NOT NULL, user_key TEXT NOT NULL, text TEXT NOT NULL);
      CREATE INDEX posts_board ON posts (board, id);
      CREATE INDEX posts_user ON posts (user_key);

      CREATE TABLE last_read (
        user_key TEXT NOT NULL, board TEXT NOT NULL, count INTEGER NOT NULL,
        PRIMARY KEY (user_key, board));

      CREATE TABLE calls (
        id INTEGER PRIMARY KEY, timestamp TEXT NOT NULL, username TEXT NOT NULL,
        user_key TEXT NOT NULL, session_id TEXT, seconds INTEGER);
      CREATE INDEX calls_user ON calls (user_key);

      CREATE TABLE oneliners (
        id INTEGER PRIMARY KEY, timestamp TEXT NOT NULL, username TEXT NOT NULL, text TEXT NOT NULL);

      CREATE TABLE profiles (
        user_key TEXT PRIMARY KEY, username TEXT NOT NULL, signature TEXT, location TEXT,
        homepage TEXT, notes TEXT, art TEXT, updated_at TEXT NOT NULL);

      CREATE TABLE trivia_scores (
        id INTEGER PRIMARY KEY, timestamp TEXT NOT NULL, username TEXT NOT NULL,
        user_key TEXT NOT NULL, points INTEGER NOT NULL, correct INTEGER NOT NULL);
      CREATE INDEX trivia_best ON trivia_scores (points DESC, timestamp);

      CREATE TABLE votes (
        poll TEXT NOT NULL, user_key TEXT NOT NULL, option TEXT NOT NULL, timestamp TEXT NOT NULL,
        PRIMARY KEY (poll, user_key));

      CREATE TABLE mail (
        id TEXT PRIMARY KEY, timestamp TEXT NOT NULL, sender TEXT NOT NULL, recipient TEXT NOT NULL,
        recipient_key TEXT NOT NULL, subject TEXT NOT NULL, body TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0);
      CREATE INDEX mail_recipient ON mail (recipient_key);
    SQL
  ].freeze

  # The database at +path+ with its schema up to date and the legacy files
  # beside it imported.
  def self.open(path)
    db = BBS::SQLite.new(path)
    db.migrate(*SCHEMA)
    LegacyImport.new(db, File.dirname(path)).run
    db
  end
end
