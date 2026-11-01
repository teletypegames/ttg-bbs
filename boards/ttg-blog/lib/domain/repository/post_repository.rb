# frozen_string_literal: true

require 'time'

# The posts table: reading, writing and the slugs. A database from before
# the slug, the face or the publishing flag gets the missing columns on
# start, and its posts get slugs.
class PostRepository
  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS posts (
      id         INTEGER PRIMARY KEY,
      title      TEXT NOT NULL,
      summary    TEXT NOT NULL DEFAULT '',
      body       TEXT NOT NULL DEFAULT '',
      category   TEXT NOT NULL,
      author_id  INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS posts_by_category ON posts (category, created_at);
    CREATE INDEX IF NOT EXISTS posts_by_date ON posts (created_at);
  SQL

  # Columns added after the first posts: ALTER TABLE adds each one missing.
  # The posts from before published stay published; a new post starts
  # unpublished (insert says so).
  COLUMNS = {
    'slug'         => 'TEXT',
    'face'         => "TEXT NOT NULL DEFAULT 'modern'",
    'published'    => 'INTEGER NOT NULL DEFAULT 1',
    'published_at' => 'TEXT'
  }.freeze

  POST_SQL = <<~SQL
    SELECT posts.*, users.name AS author FROM posts LEFT JOIN users ON users.id = posts.author_id
  SQL

  def initialize(db)
    @db = db
    @db.transaction do |conn|
      conn.execute_batch(SCHEMA)
      migrate(conn)
    end
  end

  # Posts newest first, without their bodies. +category+ nil keeps every
  # category; +published+ true or false keeps only the published or the
  # unpublished ones, nil keeps both.
  def all(category: nil, limit: nil, published: nil)
    where, args = filter(category: category, published: published)
    cap = limit ? "LIMIT #{limit.to_i}" : ''
    @db.query("#{POST_SQL} #{where} ORDER BY posts.created_at DESC, posts.id DESC #{cap}", *args)
       .map { |r| PostModel.from_row(r, body: false) }
  end

  def count(category: nil, published: nil)
    where, args = filter(category: category, published: published)
    @db.query("SELECT COUNT(*) AS n FROM posts #{where}", *args).first['n']
  end

  def find(id)
    row = @db.query("#{POST_SQL} WHERE posts.id = ?", id.to_i).first
    row && PostModel.from_row(row)
  end

  def find_by_slug(slug)
    row = @db.query("#{POST_SQL} WHERE posts.slug = ?", slug.to_s).first
    row && PostModel.from_row(row)
  end

  # The id of the new, unpublished post, with a free slug; nil when SQLite
  # failed.
  def insert(title:, summary:, body:, category:, face:, author_id:)
    now = stamp
    @db.transaction do |conn|
      conn.execute('INSERT INTO posts (slug, title, summary, body, category, face, published, author_id, ' \
                   'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
                   [free_slug(conn, PostModel.slug_base(title, Time.iso8601(now))), title, summary, body, category,
                    face, author_id, now, now])
      conn.last_insert_row_id
    end
  rescue SQLite3::Exception => e
    warn "ttg-blog-bbs: saving a post failed: #{e.message}"
    nil
  end

  # True when saved, false when SQLite failed.
  def update(id, title:, summary:, body:, category:)
    @db.query('UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? WHERE id = ?',
              title, summary, body, category, stamp, id.to_i)
    true
  rescue SQLite3::Exception => e
    warn "ttg-blog-bbs: saving post #{id} failed: #{e.message}"
    false
  end

  # Publishes the post or takes it back. The first publishing stamps
  # published_at; taking it back keeps it. True when this was the first
  # publishing, false when not, nil when there is no such post.
  def set_published(id, published)
    @db.transaction do |conn|
      row = conn.execute('SELECT published_at FROM posts WHERE id = ?', [id.to_i]).first
      next nil unless row

      first = published && row['published_at'].nil?
      conn.execute('UPDATE posts SET published = ?, published_at = COALESCE(published_at, ?) WHERE id = ?',
                   [published ? 1 : 0, first ? stamp : nil, id.to_i])
      first
    end
  end

  def delete(id) = @db.query('DELETE FROM posts WHERE id = ?', id.to_i)

  private

  def migrate(conn)
    have = conn.execute('PRAGMA table_info(posts)').map { |c| c['name'] }
    COLUMNS.each { |name, type| conn.execute("ALTER TABLE posts ADD COLUMN #{name} #{type}") unless have.include?(name) }
    conn.execute('CREATE UNIQUE INDEX IF NOT EXISTS posts_by_slug ON posts (slug)')
    conn.execute('UPDATE posts SET published_at = created_at WHERE published = 1 AND published_at IS NULL')
    conn.execute('SELECT id, title, created_at FROM posts WHERE slug IS NULL ORDER BY id').each do |row|
      conn.execute('UPDATE posts SET slug = ? WHERE id = ?',
                   [free_slug(conn, PostModel.slug_base(row['title'], Time.iso8601(row['created_at']))), row['id']])
    end
  end

  # +base+, or base-2, base-3… when a post has it already. A post keeps its
  # slug when its title changes, so a link to it keeps working.
  def free_slug(conn, base)
    base = 'post' if base.empty?
    (1..).lazy.map { |n| n == 1 ? base : "#{base}-#{n}" }
         .find { |slug| conn.execute('SELECT 1 FROM posts WHERE slug = ?', [slug]).empty? }
  end

  def filter(category:, published:)
    clauses = []
    args    = []
    if category
      clauses << 'posts.category = ?'
      args << category
    end
    clauses << "posts.published = #{published ? 1 : 0}" unless published.nil?
    [clauses.empty? ? '' : "WHERE #{clauses.join(' AND ')}", args]
  end

  def stamp = Time.now.utc.iso8601
end
