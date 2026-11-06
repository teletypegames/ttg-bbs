# frozen_string_literal: true

require 'time'

# A post of the blog, a row of the posts table (lib/domain/migrations.rb).
# +body+ is Markdown, nil when a list read the post without it; +author+ the
# editor's name, nil when they were removed; +face+ the terminal it was
# written on. +status+ is one of STATUSES: a draft is kept while an editor
# writes, an edit of +original_id+ or, without one, a new post;
# +base_updated_at+ is the original's updated_at when the edit began. The
# times are kept as ISO 8601 text and read as Time.
#
# Every read but ::find_draft and ::drafts leaves the drafts out.
class PostModel < Rubbs::Common::Storage::Model
  table :posts

  # The face a post was written on: a modern terminal or a Commodore 64.
  FACES = %w[modern petscii].freeze

  # A draft only its editors see in the composer; an unpublished post the
  # editors see; a published one everybody does.
  STATUSES = %w[draft unpublished published].freeze

  # The fields a draft carries over to its post.
  FIELDS = %i[title summary body category].freeze

  class << self
    # Posts newest first, without their bodies, at most +limit+ of them (nil:
    # all). +category+ nil keeps every category; +published+ true or false
    # keeps only the published or the unpublished ones, nil keeps both.
    def newest(category: nil, limit: nil, published: nil)
      list = kept(with_author(body: false), category: category, published: published)
        .order(Sequel.desc(Sequel[:posts][:created_at]), Sequel.desc(Sequel[:posts][:id]))
      (limit ? list.limit(Integer(limit)) : list).all
    end

    # The number of posts, as ::newest keeps them.
    def count_of(category: nil, published: nil) = kept(dataset, category: category, published: published).count

    def find_post(id) = kept(with_author, category: nil, published: nil).where(Sequel[:posts][:id] => id.to_i).first

    def find_by_slug(slug) = kept(with_author, category: nil, published: nil).where(Sequel[:posts][:slug] => slug.to_s).first

    # The id of the new, unpublished post, with a free slug. Raises
    # Sequel::DatabaseError when SQLite fails.
    def add(title:, summary:, body:, category:, face:, author_id:)
      now = stamp
      db.transaction(mode: :immediate) do
        insert(
          slug:       free_slug(slug_base(title, Time.iso8601(now))),
          title:      title,
          summary:    summary,
          body:       body,
          category:   category,
          face:       face,
          status:     'unpublished',
          author_id:  author_id,
          created_at: now,
          updated_at: now
        )
      end
    end

    # The number of posts changed. Raises Sequel::DatabaseError when SQLite
    # fails.
    def edit(id, title:, summary:, body:, category:)
      posts(id).update(title: title, summary: summary, body: body, category: category, updated_at: stamp)
    end

    # Publishes the post or takes it back. The first publishing stamps
    # published_at; taking it back keeps it. True when this was the first
    # publishing, false when not, nil when there is no such post.
    def set_published(id, published)
      db.transaction(mode: :immediate) do
        row = posts(id).select(:published_at).first
        next nil unless row

        first = published && row[:published_at].nil?
        where(id: id.to_i).update(
          status:       published ? 'published' : 'unpublished',
          published_at: Sequel.function(:coalesce, :published_at, first ? stamp : nil)
        )
        first
      end
    end

    # Deletes the post; its drafts go with it (ON DELETE CASCADE). The
    # number of posts deleted.
    def remove(id) = posts(id).delete

    # ── Drafts ─────────────────────────────────────────────────────────

    def find_draft(id) = with_author.where(Sequel[:posts][:id] => id.to_i, Sequel[:posts][:status] => 'draft').first

    # The drafts of post +original_id+, or of new posts for nil, the last
    # written first.
    def drafts(original_id)
      with_author.where(Sequel[:posts][:status] => 'draft', Sequel[:posts][:original_id] => original_id&.to_i)
        .order(Sequel.desc(Sequel[:posts][:updated_at]), Sequel.desc(Sequel[:posts][:id])).all
    end

    # Writes the fields into draft +id+; a new draft when +id+ is nil or the
    # draft is gone (discarded or saved meanwhile). The id of the draft; nil
    # when the original is gone. Raises Sequel::DatabaseError when SQLite
    # fails.
    def save_draft(id, fields, original_id:, base_updated_at:, author_id:, face:)
      now = stamp
      db.transaction(mode: :immediate) do
        changed = id && draft(id).update(**fields.slice(*FIELDS), updated_at: now)
        next id.to_i if changed&.positive?
        next nil if original_id && posts(original_id).empty?

        insert(
          **fields.slice(*FIELDS),
          face:            face,
          status:          'draft',
          original_id:     original_id&.to_i,
          base_updated_at: base_updated_at,
          author_id:       author_id,
          created_at:      now,
          updated_at:      now
        )
      end
    end

    # Saves draft +id+: an edit is written into its original and the draft
    # deleted; a new post becomes an unpublished post with a slug, dated now,
    # keeping its id. The id of the post, or a Symbol: :gone when there is no
    # such draft or original, :conflict when the original was saved since the
    # edit began (unless +force+). Raises Sequel::DatabaseError when SQLite
    # fails.
    def commit_draft(id, force: false)
      db.transaction(mode: :immediate) do
        draft = draft(id).first
        next :gone unless draft

        draft[:original_id] ? commit_edit(draft, force) : commit_new(draft)
      end
    end

    # Deletes draft +id+; the number of rows deleted.
    def discard(id) = draft(id).delete

    # A post not saved, for the composer's preview: +fields+ (FIELDS) by
    # +author+ (a name) on +face+, published and dated now.
    def preview(fields, author:, face:)
      now = Time.now.iso8601
      load(
        id:              0,
        slug:            '',
        **fields.slice(*FIELDS),
        author:          author,
        face:            face,
        status:          'published',
        original_id:     nil,
        base_updated_at: nil,
        published_at:    nil,
        created_at:      now,
        updated_at:      now
      )
    end

    # The address of a post on the web: its date and its title, in plain
    # lower-case ASCII ("2026-10-28-hello-world").
    def slug_base(title, time)
      words = title.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
      [time.utc.strftime('%Y-%m-%d'), words[0, 60].sub(/-\z/, '')].reject(&:empty?).join('-')
    end

    # +base+, or base-2, base-3… when a post of +posts+ (a dataset of the
    # posts table) has it already. A post keeps its slug when its title
    # changes, so a link to it keeps working.
    def free_slug(base, posts = dataset)
      base = 'post' if base.empty?
      (1..).lazy.map { |n| n == 1 ? base : "#{base}-#{n}" }.find { |slug| posts.where(slug: slug).empty? }
    end

    private

    # The posts with their author's name (+author+), the body left out
    # unless +body+.
    def with_author(body: true)
      columns = body ? [Sequel[:posts].*] : (self.columns - [:body]).map { |c| Sequel[:posts][c] }
      dataset.select(*columns, Sequel[:users][:name].as(:author)).left_join(:users, id: :author_id)
    end

    # The post +id+ (not a draft) as a dataset.
    def posts(id) = where(id: id.to_i).exclude(status: 'draft')

    # The draft +id+ as a dataset.
    def draft(id) = where(id: id.to_i, status: 'draft')

    # +list+ with the drafts left out, and kept to +category+ and the
    # +published+ ones when they are given.
    def kept(list, category:, published:)
      list = case published
             when nil then list.exclude(Sequel[:posts][:status] => 'draft')
             else list.where(Sequel[:posts][:status] => published ? 'published' : 'unpublished')
             end
      category ? list.where(Sequel[:posts][:category] => category) : list
    end

    def commit_edit(draft, force)
      original = posts(draft[:original_id]).select(:updated_at).first
      return :gone unless original
      return :conflict if !force && original[:updated_at] != draft[:base_updated_at]

      where(id: draft[:original_id]).update(**draft.values.slice(*FIELDS), updated_at: stamp)
      where(id: draft.id).delete
      draft[:original_id]
    end

    def commit_new(draft)
      now = stamp
      where(id: draft.id).update(
        status:          'unpublished',
        slug:            free_slug(slug_base(draft[:title], Time.iso8601(now))),
        base_updated_at: nil,
        created_at:      now,
        updated_at:      now
      )
      draft.id
    end

    def stamp = Time.now.utc.iso8601
  end

  # The editor's name, nil when they were removed.
  def author = self[:author]

  def created_at = Time.iso8601(self[:created_at])

  def updated_at = Time.iso8601(self[:updated_at])

  def published_at = self[:published_at] && Time.iso8601(self[:published_at])

  # FIELDS of the post.
  def fields = values.slice(*FIELDS)

  def published? = status == 'published'

  def draft? = status == 'draft'

  def updated? = updated_at - created_at >= 60
end
