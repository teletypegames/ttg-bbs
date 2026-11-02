# frozen_string_literal: true

require 'time'

# The posts table (BlogSchema): reading, writing and the slugs, and the
# drafts. Every read but #find_draft and #drafts leaves the drafts out.
class PostRepository
  POST_SQL = <<~SQL
    SELECT posts.*, users.name AS author FROM posts LEFT JOIN users ON users.id = posts.author_id
  SQL

  INSERT_SQL = <<~SQL
    INSERT INTO posts (slug, title, summary, body, category, face, status, author_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 'unpublished', ?, ?, ?)
  SQL

  DRAFT_SQL = <<~SQL
    INSERT INTO posts (title, summary, body, category, face, status, original_id, base_updated_at, author_id,
                       created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, 'draft', ?, ?, ?, ?, ?)
  SQL

  NOT_DRAFT = "posts.status <> 'draft'"

  # The fields a draft carries over to its post.
  FIELDS = %i[title summary body category].freeze

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

  def find(id) = post(@db.get("#{POST_SQL} WHERE posts.id = ? AND #{NOT_DRAFT}", id.to_i))

  def find_by_slug(slug) = post(@db.get("#{POST_SQL} WHERE posts.slug = ? AND #{NOT_DRAFT}", slug.to_s))

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
    @db.change("UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? WHERE id = ? AND #{NOT_DRAFT}",
               title, summary, body, category, stamp, id.to_i)
  end

  # Publishes the post or takes it back. The first publishing stamps
  # published_at; taking it back keeps it. True when this was the first
  # publishing, false when not, nil when there is no such post.
  def set_published(id, published)
    @db.transaction do
      row = @db.get("SELECT published_at FROM posts WHERE id = ? AND #{NOT_DRAFT}", id.to_i)
      next nil unless row

      first = published && row['published_at'].nil?
      @db.change('UPDATE posts SET status = ?, published_at = COALESCE(published_at, ?) WHERE id = ?',
                 published ? 'published' : 'unpublished', first ? stamp : nil, id.to_i)
      first
    end
  end

  # Deletes the post; its drafts go with it (ON DELETE CASCADE).
  def delete(id) = @db.change("DELETE FROM posts WHERE id = ? AND #{NOT_DRAFT}", id.to_i)

  # ── Drafts ─────────────────────────────────────────────────────────────

  def find_draft(id) = post(@db.get("#{POST_SQL} WHERE posts.id = ? AND posts.status = 'draft'", id.to_i))

  # The drafts of post +original_id+, or of new posts for nil, the last
  # written first.
  def drafts(original_id)
    @db.query("#{POST_SQL} WHERE posts.status = 'draft' AND posts.original_id IS ? " \
              'ORDER BY posts.updated_at DESC, posts.id DESC', original_id&.to_i)
       .map { |r| PostModel.from_row(r) }
  end

  # Writes the fields into draft +id+; a new draft when +id+ is nil or the
  # draft is gone (discarded or saved meanwhile). The id of the draft; nil
  # when the original is gone. Raises SQLite3::Exception when SQLite fails.
  def save_draft(id, fields, original_id:, base_updated_at:, author_id:, face:)
    now = stamp
    @db.transaction do
      changed = id && @db.change('UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? ' \
                                 "WHERE id = ? AND status = 'draft'", *fields.values_at(*FIELDS), now, id.to_i)
      next id.to_i if changed&.positive?
      next nil if original_id && !@db.get("SELECT 1 FROM posts WHERE id = ? AND #{NOT_DRAFT}", original_id.to_i)

      @db.insert(DRAFT_SQL, *fields.values_at(*FIELDS), face, original_id&.to_i, base_updated_at, author_id, now, now)
    end
  end

  # Saves draft +id+: an edit is written into its original and the draft
  # deleted; a new post becomes an unpublished post with a slug, dated now,
  # keeping its id. The id of the post, or a Symbol: :gone when there is no
  # such draft or original, :conflict when the original was saved since the
  # edit began (unless +force+). Raises SQLite3::Exception when SQLite fails.
  def commit_draft(id, force: false)
    @db.transaction do
      draft = @db.get("SELECT * FROM posts WHERE id = ? AND status = 'draft'", id.to_i)
      next :gone unless draft

      draft['original_id'] ? commit_edit(draft, force) : commit_new(draft)
    end
  end

  # Deletes draft +id+; the number of rows deleted.
  def discard(id) = @db.change("DELETE FROM posts WHERE id = ? AND status = 'draft'", id.to_i)

  private

  def commit_edit(draft, force)
    original = @db.get("SELECT updated_at FROM posts WHERE id = ? AND #{NOT_DRAFT}", draft['original_id'])
    return :gone unless original
    return :conflict if !force && original['updated_at'] != draft['base_updated_at']

    @db.change('UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? WHERE id = ?',
               *draft.values_at(*FIELDS.map(&:to_s)), stamp, draft['original_id'])
    @db.change('DELETE FROM posts WHERE id = ?', draft['id'])
    draft['original_id']
  end

  def commit_new(draft)
    now  = stamp
    slug = BlogSchema.free_slug(@db, PostModel.slug_base(draft['title'], Time.iso8601(now)))
    @db.change("UPDATE posts SET status = 'unpublished', slug = ?, base_updated_at = NULL, created_at = ?, " \
               'updated_at = ? WHERE id = ?', slug, now, now, draft['id'])
    draft['id']
  end

  def post(row) = row && PostModel.from_row(row)

  def status_clause(published)
    return NOT_DRAFT if published.nil?

    published ? "posts.status = 'published'" : "posts.status = 'unpublished'"
  end

  def filter(category:, published:)
    clauses = [status_clause(published)]
    args    = []
    if category
      clauses << 'posts.category = ?'
      args << category
    end
    ["WHERE #{clauses.join(' AND ')}", args]
  end

  def stamp = Time.now.utc.iso8601
end
