# frozen_string_literal: true

# The schema of the callers' ratings and lists, one step per version
# (Rubbs::Common::Storage::Database.migrate). A rating keeps the film's
# title and year, so the lists show without asking Wikidata.
MIGRATIONS = [<<~SQL].freeze
  CREATE TABLE ratings (
    id            INTEGER PRIMARY KEY,
    account_id    TEXT NOT NULL,
    handle        TEXT NOT NULL,
    film_id       TEXT NOT NULL,
    title         TEXT NOT NULL,
    year          INTEGER,
    stars         INTEGER NOT NULL,
    review        TEXT NOT NULL DEFAULT '',
    review_status TEXT NOT NULL DEFAULT 'none',
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL,
    UNIQUE (account_id, film_id)
  );
  CREATE INDEX ratings_film ON ratings (film_id);
  CREATE INDEX ratings_review ON ratings (review_status, updated_at);
  CREATE TABLE marks (
    account_id TEXT NOT NULL,
    film_id    TEXT NOT NULL,
    kind       TEXT NOT NULL,
    title      TEXT NOT NULL,
    year       INTEGER,
    created_at TEXT NOT NULL,
    PRIMARY KEY (account_id, film_id, kind)
  );
SQL
