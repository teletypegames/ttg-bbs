# frozen_string_literal: true

require 'test_helper'

# MIGRATIONS (BlogSchema): a new file, and the files the board wrote before it had
# versions, which must keep every row.
class SchemaTest < Minitest::Test
  include TestHelper

  # The first shape of the board: no slug, face or publishing flag yet.
  FIRST_SHAPE = <<~SQL
    CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE,
                        password_digest TEXT NOT NULL, created_at TEXT NOT NULL);
    CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT NOT NULL, summary TEXT NOT NULL DEFAULT '',
                        body TEXT NOT NULL DEFAULT '', category TEXT NOT NULL,
                        author_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                        created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
    INSERT INTO users VALUES (1, 'tasi', 'pbkdf2-sha256$1$c2FsdA==$aGFzaA==', '2026-10-28T10:00:00Z');
    INSERT INTO posts VALUES (1, 'Hello world', '', 'one', 'news', 1, '2026-10-28T10:00:00Z', '2026-10-28T10:00:00Z');
    INSERT INTO posts VALUES (2, 'Hello world', 'x', 'two', 'news', 1, '2026-10-28T11:00:00Z', '2026-10-28T11:00:00Z');
  SQL

  # The last shape before versions, as the board left it in production.
  LAST_SHAPE = <<~SQL.freeze
    #{FIRST_SHAPE}
    ALTER TABLE posts ADD COLUMN slug TEXT;
    ALTER TABLE posts ADD COLUMN face TEXT NOT NULL DEFAULT 'modern';
    ALTER TABLE posts ADD COLUMN published INTEGER NOT NULL DEFAULT 1;
    ALTER TABLE posts ADD COLUMN published_at TEXT;
    CREATE INDEX posts_by_category ON posts (category, created_at);
    CREATE INDEX posts_by_date ON posts (created_at);
    CREATE UNIQUE INDEX posts_by_slug ON posts (slug);
    UPDATE posts SET slug = 'kept-slug', published_at = '2026-10-29T09:00:00Z' WHERE id = 1;
    UPDATE posts SET slug = 'draft-slug', published = 0, face = 'petscii' WHERE id = 2;
  SQL

  # A file at +legacy_path+ written by +sql+, and the blog on it.
  def legacy(sql)
    SQLite3::Database.new(legacy_path) { |raw| raw.execute_batch(sql) }
    with_env(legacy_path, CATEGORIES)
    @blog = nil
  end

  def legacy_path = File.join(@dir, 'legacy.sqlite3')

  def columns(db) = db.fetch('PRAGMA table_info(posts)').map { |c| c[:name] }

  def test_a_new_file_gets_every_table_at_version_two
    assert_equal 2, BBS::Database.version(@db)
    assert_equal [], %w[published_at status original_id base_updated_at] - columns(@db)
    refute_includes columns(@db), 'published'
    assert_equal 0, PostModel.count
  end

  def test_the_last_shape_keeps_every_row_as_it_was
    legacy(LAST_SHAPE)
    first  = blog.posts.find(1)
    second = blog.posts.find(2)
    assert_equal ['kept-slug', true, 'modern', 'tasi'], [first.slug, first.published?, first.face, first.author]
    assert_equal ['draft-slug', false, 'petscii'], [second.slug, second.published?, second.face]
    assert_equal Time.utc(2026, 10, 29, 9), first.published_at
    assert_equal 2, BBS::Database.version(blog.databases[:main])
  end

  # Version 1, as the board left it before the drafts: the flag becomes
  # the status, and the flag goes.
  def test_version_one_turns_the_flag_into_the_status
    legacy(LAST_SHAPE)
    db = Sequel.sqlite(legacy_path)
    assert_equal 1, BBS::Database.migrate(db, [BlogSchema::BEFORE_VERSIONS])
    assert_equal 2, BBS::Database.migrate(db, MIGRATIONS)
    rows = db.fetch('SELECT id, slug, status, original_id FROM posts ORDER BY id').map(&:values)
    assert_equal [[1, 'kept-slug', 'published', nil], [2, 'draft-slug', 'unpublished', nil]], rows
    refute_includes columns(db), 'published'
  end

  def test_the_first_shape_gets_the_new_columns_and_slugs
    legacy(FIRST_SHAPE)
    posts = blog.posts.all.sort_by(&:id)
    assert_equal %w[2026-10-28-hello-world 2026-10-28-hello-world-2], posts.map(&:slug)
    assert(posts.all?(&:published?))
    assert_equal Time.utc(2026, 10, 28, 10), posts.first.published_at
  end

  def test_a_second_start_changes_nothing
    legacy(LAST_SHAPE)
    BBS::Database.open(legacy_path, MIGRATIONS).disconnect
    before = SQLite3::Database.new(legacy_path).execute('SELECT * FROM posts ORDER BY id')
    assert_equal 2, BBS::Database.version(BBS::Database.open(legacy_path, MIGRATIONS))
    assert_equal before, SQLite3::Database.new(legacy_path).execute('SELECT * FROM posts ORDER BY id')
  end

  def test_a_new_post_after_the_migration_gets_a_free_slug
    legacy(FIRST_SHAPE)
    post = blog.posts.create(author: UserModel.credentials('tasi').first, **draft)
    assert_match(/\A\d{4}-\d\d-\d\d-hello-world\z/, post.slug)
    refute post.published?
  end
end
