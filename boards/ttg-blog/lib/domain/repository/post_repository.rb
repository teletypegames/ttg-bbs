# frozen_string_literal: true

require 'time'

# The posts table (BlogSchema): reading, writing and the slugs.
class PostRepository
  POST_SQL = <<~SQL
    SELECT posts.*, users.name AS author FROM posts LEFT JOIN users ON users.id = posts.author_id
  SQL

  INSERT_SQL = <<~SQL
    INSERT INTO posts (slug, title, summary, body, category, face, published, author_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
  SQL

  # +db+ is a BBS::SQLite whose schema BlogSchema brought up to date.
  def initialize(db)
    @db = db
  end

  # Posts newest first, without their bodies, at most +limit+ of them (nil:
  # all). +category+ nil keeps every category; +published+ true or false
  # keeps only the published or the unpublished ones, nil keeps both.
  def all(category: nil, limit: nil, published: nil)
    where, args = filter(category: category, published: published)
    cap = limit ? "LIMIT #{Integer(limit)}" : ''
    @db.query("#{POST_SQL} #{where} ORDER BY posts.created_at DESC, posts.id DESC #{cap}", *args)
       .map { |r| PostModel.from_row(r, body: false) }
  end

  def count(category: nil, published: nil)
    where, args = filter(category: category, published: published)
    @db.get("SELECT COUNT(*) AS n FROM posts #{where}", *args)['n']
  end

  def find(id) = post(@db.get("#{POST_SQL} WHERE posts.id = ?", id.to_i))

  def find_by_slug(slug) = post(@db.get("#{POST_SQL} WHERE posts.slug = ?", slug.to_s))

  # The id of the new, unpublished post, with a free slug. Raises
  # SQLite3::Exception when SQLite fails.
  def insert(title:, summary:, body:, category:, face:, author_id:)
    now = stamp
    @db.transaction do
      slug = BlogSchema.free_slug(@db, PostModel.slug_base(title, Time.iso8601(now)))
      @db.insert(INSERT_SQL, slug, title, summary, body, category, face, author_id, now, now)
    end
  end

  # The number of posts changed. Raises SQLite3::Exception when SQLite
  # fails.
  def update(id, title:, summary:, body:, category:)
    @db.change('UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? WHERE id = ?',
               title, summary, body, category, stamp, id.to_i)
  end

  # Publishes the post or takes it back. The first publishing stamps
  # published_at; taking it back keeps it. True when this was the first
  # publishing, false when not, nil when there is no such post.
  def set_published(id, published)
    @db.transaction do
      row = @db.get('SELECT published_at FROM posts WHERE id = ?', id.to_i)
      next nil unless row

      first = published && row['published_at'].nil?
      @db.change('UPDATE posts SET published = ?, published_at = COALESCE(published_at, ?) WHERE id = ?',
                 published ? 1 : 0, first ? stamp : nil, id.to_i)
      first
    end
  end

  def delete(id) = @db.change('DELETE FROM posts WHERE id = ?', id.to_i)

  private

  def post(row) = row && PostModel.from_row(row)

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
