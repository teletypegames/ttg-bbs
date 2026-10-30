# frozen_string_literal: true

require 'fileutils'
require 'openssl'
require 'securerandom'
require 'sqlite3'
require 'time'
require 'yaml'

# The blog in one SQLite file: the editors who may log in and write, and the
# posts they write. The categories are not in the database: they come from a
# YAML file, and a post names its category by id. A post whose category left
# the file keeps it, and shows it by its id.
#
# One connection serves every call of the board, behind a mutex: the board
# is one process with a thread per caller, and a blog is written rarely.
class Blog
  Category = Data.define(:id, :name, :about)
  User     = Data.define(:id, :name)
  Post     = Data.define(:id, :slug, :title, :summary, :body, :category, :author, :face, :created_at, :updated_at) do
    def updated? = updated_at - created_at >= 60
  end

  MAX_TITLE   = 80
  MAX_SUMMARY = 280
  MAX_BODY    = 64 * 1024
  MAX_NAME    = 24
  MIN_PASS    = 8

  ITERATIONS = 200_000

  # The face a post was written on: a modern terminal or a Commodore 64.
  FACES = %w[modern petscii].freeze

  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS users (
      id              INTEGER PRIMARY KEY,
      name            TEXT NOT NULL UNIQUE COLLATE NOCASE,
      password_digest TEXT NOT NULL,
      created_at      TEXT NOT NULL
    );
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
  COLUMNS = {
    'slug' => 'TEXT',
    'face' => "TEXT NOT NULL DEFAULT 'modern'"
  }.freeze

  POST_SQL = <<~SQL
    SELECT posts.*, users.name AS author FROM posts LEFT JOIN users ON users.id = posts.author_id
  SQL

  def self.load_categories(path)
    Array(YAML.safe_load_file(path)).map do |c|
      Category.new(id: c.fetch('id').to_s, name: c.fetch('name').to_s, about: c['about'].to_s)
    end
  end

  attr_reader :categories

  def initialize(path:, categories:)
    FileUtils.mkdir_p(File.dirname(path))
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
    @db.busy_timeout = 5000
    @db.execute('PRAGMA journal_mode = WAL')
    @db.execute('PRAGMA foreign_keys = ON')
    @db.execute_batch(SCHEMA)
    migrate
    @categories = categories
    @mutex      = Mutex.new
    @listeners  = []
  end

  # The block is called with every new post, after it is saved.
  def on_publish(&block) = @listeners << block

  # The address of a post on the web: its date and its title, in plain
  # lower-case ASCII ("2026-10-28-hello-world").
  def self.slug_base(title, time)
    words = title.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
    [time.utc.strftime('%Y-%m-%d'), words[0, 60].sub(/-\z/, '')].reject(&:empty?).join('-')
  end

  def category(id) = @categories.find { |c| c.id == id } || Category.new(id: id, name: id, about: '')

  # Posts newest first, all of them or one category's; without their bodies.
  def posts(category: nil, limit: nil)
    where = category ? 'WHERE posts.category = ?' : ''
    cap   = limit ? "LIMIT #{limit.to_i}" : ''
    query("#{POST_SQL} #{where} ORDER BY posts.created_at DESC, posts.id DESC #{cap}", *[category].compact)
      .map { |r| post_of(r, body: false) }
  end

  def total = query('SELECT COUNT(*) AS n FROM posts').first['n']

  def count(category) = query('SELECT COUNT(*) AS n FROM posts WHERE category = ?', category).first['n']

  def post(id)
    row = query("#{POST_SQL} WHERE posts.id = ?", id.to_i).first
    row && post_of(row)
  end

  def post_by_slug(slug)
    row = query("#{POST_SQL} WHERE posts.slug = ?", slug.to_s).first
    row && post_of(row)
  end

  # The new Post, or a Symbol naming what is wrong with it.
  def create(author:, title:, summary:, body:, category:, face: 'modern')
    problem = check(title, summary, body, category)
    return problem if problem

    now = stamp
    id = transaction do
      @db.execute('INSERT INTO posts (slug, title, summary, body, category, face, author_id, created_at, updated_at) ' \
                  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                  [free_slug(Blog.slug_base(title, Time.iso8601(now))), title.strip, summary.strip, body, category,
                   FACES.include?(face) ? face : 'modern', author.id, now, now])
      @db.last_insert_row_id
    end
    created = post(id)
    publish(created)
    created
  end

  # The Post as saved, or a Symbol naming what is wrong with it.
  def update(id, title:, summary:, body:, category:)
    problem = check(title, summary, body, category)
    return problem if problem

    query('UPDATE posts SET title = ?, summary = ?, body = ?, category = ?, updated_at = ? WHERE id = ?',
          title.strip, summary.strip, body, category, stamp, id.to_i)
    post(id)
  end

  def delete(id) = query('DELETE FROM posts WHERE id = ?', id.to_i)

  # The User whose name and password these are, or nil. A name nobody has
  # still costs a key derivation, so the time taken does not tell it apart.
  def authenticate(name, password)
    row = query('SELECT * FROM users WHERE name = ?', name.to_s.strip).first
    digest = row ? row['password_digest'] : Blog.digest('')
    return nil unless Blog.password?(digest, password.to_s) && row

    User.new(id: row['id'], name: row['name'])
  end

  def users = query('SELECT id, name FROM users ORDER BY name').map { |r| User.new(id: r['id'], name: r['name']) }

  # :ok, or a Symbol naming what is wrong.
  def add_user(name, password)
    name = name.to_s.strip
    return :bad_name unless name.match?(/\A[A-Za-z0-9_.-]{2,#{MAX_NAME}}\z/o)
    return :short_password if password.to_s.length < MIN_PASS
    return :taken if query('SELECT 1 FROM users WHERE name = ?', name).any?

    query('INSERT INTO users (name, password_digest, created_at) VALUES (?, ?, ?)', name, Blog.digest(password), stamp)
    :ok
  end

  def set_password(name, password)
    return :short_password if password.to_s.length < MIN_PASS

    changed = change('UPDATE users SET password_digest = ? WHERE name = ?', Blog.digest(password), name.to_s.strip)
    changed.positive? ? :ok : :no_user
  end

  # The posts of a removed editor stay, without an author.
  def remove_user(name)
    change('DELETE FROM users WHERE name = ?', name.to_s.strip).positive? ? :ok : :no_user
  end

  # PBKDF2-SHA256 with a random salt, as "pbkdf2-sha256$iterations$salt$hash".
  def self.digest(password, salt: SecureRandom.bytes(16), iterations: ITERATIONS)
    hash = OpenSSL::KDF.pbkdf2_hmac(password.to_s, salt: salt, iterations: iterations, length: 32, hash: 'sha256')
    ['pbkdf2-sha256', iterations, [salt].pack('m0'), [hash].pack('m0')].join('$')
  end

  def self.password?(digest, password)
    kind, iterations, salt, hash = digest.to_s.split('$')
    return false unless kind == 'pbkdf2-sha256' && hash

    fresh = digest(password, salt: salt.unpack1('m0'), iterations: iterations.to_i)
    OpenSSL.fixed_length_secure_compare(fresh, digest)
  rescue ArgumentError
    false
  end

  private

  def migrate
    have = @db.execute('PRAGMA table_info(posts)').map { |c| c['name'] }
    COLUMNS.each { |name, type| @db.execute("ALTER TABLE posts ADD COLUMN #{name} #{type}") unless have.include?(name) }
    @db.execute('CREATE UNIQUE INDEX IF NOT EXISTS posts_by_slug ON posts (slug)')
    @db.execute('SELECT id, title, created_at FROM posts WHERE slug IS NULL ORDER BY id').each do |row|
      @db.execute('UPDATE posts SET slug = ? WHERE id = ?',
                  [free_slug(Blog.slug_base(row['title'], Time.iso8601(row['created_at']))), row['id']])
    end
  end

  # +base+, or base-2, base-3… when a post has it already. A post keeps its
  # slug when its title changes, so a link to it keeps working.
  def free_slug(base)
    base = 'post' if base.empty?
    (1..).lazy.map { |n| n == 1 ? base : "#{base}-#{n}" }
         .find { |slug| @db.execute('SELECT 1 FROM posts WHERE slug = ?', [slug]).empty? }
  end

  # A listener that fails does not fail the post: it is saved already.
  def publish(post)
    @listeners.each do |listener|
      listener.call(post)
    rescue StandardError => e
      warn "ttgblog: on_publish failed: #{e.class}: #{e.message}"
    end
  end

  def check(title, summary, body, category)
    return :no_title if title.to_s.strip.empty?
    return :long_title if title.length > MAX_TITLE
    return :long_summary if summary.to_s.length > MAX_SUMMARY
    return :long_body if body.to_s.bytesize > MAX_BODY
    return :bad_category unless @categories.any? { |c| c.id == category }

    nil
  end

  def query(sql, *args) = @mutex.synchronize { @db.execute(sql, args) }

  def change(sql, *args)
    @mutex.synchronize do
      @db.execute(sql, args)
      @db.changes
    end
  end

  def transaction(&) = @mutex.synchronize { @db.transaction(&) }

  def stamp = Time.now.utc.iso8601

  def post_of(row, body: true)
    Post.new(id: row['id'], slug: row['slug'], title: row['title'], summary: row['summary'],
             body: body ? row['body'] : nil, category: row['category'], author: row['author'], face: row['face'],
             created_at: Time.iso8601(row['created_at']), updated_at: Time.iso8601(row['updated_at']))
  end
end
