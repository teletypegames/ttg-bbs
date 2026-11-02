# frozen_string_literal: true

require 'time'

# The tables of the blog, as BBS::SQLite#migrate steps. Step 1 is the
# schema the board grew before it had versions: it creates what a new file
# lacks and adds what an older one lacks, so a file the board wrote before
# (user_version 0, in any of its shapes) keeps every row and comes out at
# version 1 with nothing else changed.
module BlogSchema
  TABLES = [<<~SQL, <<~SQL].freeze
    CREATE TABLE IF NOT EXISTS users (
      id              INTEGER PRIMARY KEY,
      name            TEXT NOT NULL UNIQUE COLLATE NOCASE,
      password_digest TEXT NOT NULL,
      created_at      TEXT NOT NULL
    )
  SQL
    CREATE TABLE IF NOT EXISTS posts (
      id         INTEGER PRIMARY KEY,
      title      TEXT NOT NULL,
      summary    TEXT NOT NULL DEFAULT '',
      body       TEXT NOT NULL DEFAULT '',
      category   TEXT NOT NULL,
      author_id  INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  SQL

  # The columns the posts got after the first ones. The posts from before
  # the publishing flag stay published; a new post starts unpublished
  # (PostRepository#insert says so).
  COLUMNS = {
    'slug'         => 'TEXT',
    'face'         => "TEXT NOT NULL DEFAULT 'modern'",
    'published'    => 'INTEGER NOT NULL DEFAULT 1',
    'published_at' => 'TEXT'
  }.freeze

  INDEXES = [
    'CREATE INDEX IF NOT EXISTS posts_by_category ON posts (category, created_at)',
    'CREATE INDEX IF NOT EXISTS posts_by_date ON posts (created_at)',
    'CREATE UNIQUE INDEX IF NOT EXISTS posts_by_slug ON posts (slug)'
  ].freeze

  BEFORE_VERSIONS = lambda do |db|
    TABLES.each { |sql| db.query(sql) }
    have = db.query('PRAGMA table_info(posts)').map { |c| c['name'] }
    COLUMNS.each { |name, type| db.query("ALTER TABLE posts ADD COLUMN #{name} #{type}") unless have.include?(name) }
    INDEXES.each { |sql| db.query(sql) }
    db.query('UPDATE posts SET published_at = created_at WHERE published = 1 AND published_at IS NULL')
    BlogSchema.give_slugs(db)
  end

  # Step 2: a status in place of the publishing flag, and the drafts. A
  # draft is a row of its own: with an original_id it is an edit of that
  # post, without one a new post; base_updated_at is the original's
  # updated_at when the edit began, to tell an edit saved meanwhile.
  STATUS = <<~SQL
    ALTER TABLE posts ADD COLUMN status TEXT NOT NULL DEFAULT 'unpublished'
      CHECK (status IN ('draft', 'unpublished', 'published'));
    ALTER TABLE posts ADD COLUMN original_id INTEGER REFERENCES posts(id) ON DELETE CASCADE;
    ALTER TABLE posts ADD COLUMN base_updated_at TEXT;
    UPDATE posts SET status = CASE published WHEN 1 THEN 'published' ELSE 'unpublished' END;
    ALTER TABLE posts DROP COLUMN published;
    CREATE INDEX posts_by_status ON posts (status, created_at);
    CREATE INDEX posts_drafts ON posts (original_id) WHERE status = 'draft';
  SQL

  # Brings the file of +db+ (a BBS::SQLite) up to date; the version reached.
  def self.migrate(db) = db.migrate(BEFORE_VERSIONS, STATUS)

  # A slug for each post without one, from its title and date.
  def self.give_slugs(db)
    db.query('SELECT id, title, created_at FROM posts WHERE slug IS NULL ORDER BY id').each do |row|
      base = PostModel.slug_base(row['title'], Time.iso8601(row['created_at']))
      db.change('UPDATE posts SET slug = ? WHERE id = ?', free_slug(db, base), row['id'])
    end
  end

  # +base+, or base-2, base-3… when a post has it already. A post keeps its
  # slug when its title changes, so a link to it keeps working.
  def self.free_slug(db, base)
    base = 'post' if base.empty?
    (1..).lazy.map { |n| n == 1 ? base : "#{base}-#{n}" }
         .find { |slug| db.get('SELECT 1 FROM posts WHERE slug = ?', slug).nil? }
  end
end
