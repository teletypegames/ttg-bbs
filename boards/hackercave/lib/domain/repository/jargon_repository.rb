# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'sqlite3'

# The Jargon File in SQLite (data/jargon.sqlite3), built from the plain text
# shipped with the board (config/jargon/jarg447.txt, JargonParser) when the
# database is missing or was built from another file: the lexicon's
# entries, the other parts as sections, and a full-text index of the
# headwords and the text (FTS5). One read-only connection behind a Mutex.
class JargonRepository
  def initialize(path, source:)
    @path   = path
    @source = source
    @lock   = Mutex.new
  end

  # Builds the database when the source file changed. Returns :built or
  # :fresh.
  def prepare
    digest = Digest::SHA256.file(@source).hexdigest
    return :fresh if built_from == digest

    build(digest)
    :built
  end

  def count = query('SELECT COUNT(*) AS n FROM entries').first&.fetch('n') || 0

  def entry(id) = query('SELECT * FROM entries WHERE id = ?', [Integer(id)]).map { |r| entry_of(r) }.first

  # The entries of these headwords ({links}), in their order; the unknown
  # ones left out.
  def by_headwords(headwords)
    keys = headwords.map { |h| JargonEntryModel.key(h) }.uniq
    return [] if keys.empty?

    found = query("SELECT * FROM entries WHERE key IN (#{(['?'] * keys.size).join(',')})", keys).to_h { |r|
      [r['key'], entry_of(r)]
    }
    keys.filter_map { |k| found[k] }
  end

  # The entries whose headword starts with +letter+ (a letter, or "0" for
  # the ones that start with no letter), in the order of the File.
  def letter(letter)
    sql = letter == '0' ? "NOT (upper(substr(headword, 1, 1)) BETWEEN 'A' AND 'Z')" : 'upper(substr(headword, 1, 1)) = ?'
    query("SELECT * FROM entries WHERE #{sql} ORDER BY id", letter == '0' ? [] : [letter]).map { |r| entry_of(r) }
  end

  # How many entries each letter has: [['0', 12], ['A', 160], …].
  def letters
    query("SELECT CASE WHEN upper(substr(headword, 1, 1)) BETWEEN 'A' AND 'Z' THEN upper(substr(headword, 1, 1)) " \
          "ELSE '0' END AS l, COUNT(*) AS n FROM entries GROUP BY l ORDER BY l").map { |r| [r['l'], r['n']] }
  end

  # At most +limit+ entries that have every word of +words+ (a word
  # prefix): the entry whose headword is the words first, then the headword
  # weighing most.
  def search(words, limit:)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    query('SELECT e.* FROM entries_fts f JOIN entries e ON e.id = f.rowid WHERE entries_fts MATCH ? ' \
          'ORDER BY e.key = ? DESC, bm25(entries_fts, 20.0, 1.0) LIMIT ?',
          [terms, JargonEntryModel.key(words.join(' ')), limit]).map { |r| entry_of(r) }
  end

  def sections = query('SELECT * FROM sections ORDER BY id').map { |r| section_of(r) }

  private

  def built_from
    return nil unless File.exist?(@path)

    query("SELECT value FROM meta WHERE key = 'source'").first&.fetch('value')
  end

  def build(digest)
    parsed = JargonParser.new(File.binread(@source))
    tmp = "#{@path}.new"
    write(tmp, parsed, digest)
    @lock.synchronize do
      @db&.close
      @db = nil
      File.rename(tmp, @path)
    end
    BBS.log('jargon', "built: #{parsed.entries.size} entries, #{parsed.sections.size} sections")
  ensure
    FileUtils.rm_f(tmp) if tmp
  end

  def write(tmp, parsed, digest)
    FileUtils.mkdir_p(File.dirname(tmp))
    FileUtils.rm_f(tmp)
    db = SQLite3::Database.new(tmp)
    db.execute_batch(<<~SQL)
      CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
      CREATE TABLE entries (id INTEGER PRIMARY KEY, headword TEXT, key TEXT, pron TEXT, body TEXT);
      CREATE INDEX entries_key ON entries (key);
      CREATE TABLE sections (id INTEGER PRIMARY KEY, title TEXT, body TEXT);
      CREATE VIRTUAL TABLE entries_fts USING fts5(headword, body, tokenize='unicode61 remove_diacritics 2');
    SQL
    db.transaction { fill(db, parsed, digest) }
  ensure
    db&.close
  end

  def fill(db, parsed, digest)
    parsed.entries.each do |e|
      db.execute('INSERT INTO entries VALUES (?, ?, ?, ?, ?)',
                 [e.id, e.headword, JargonEntryModel.key(e.headword), e.pron, JSON.generate(e.paragraphs)])
      db.execute('INSERT INTO entries_fts (rowid, headword, body) VALUES (?, ?, ?)',
                 [e.id, e.headword, e.paragraphs.map(&:last).join(' ')])
    end
    parsed.sections.each { |s| db.execute('INSERT INTO sections VALUES (?, ?, ?)', [s.id, s.title, JSON.generate(s.paragraphs)]) }
    db.execute("INSERT INTO meta VALUES ('source', ?)", [digest])
  end

  def entry_of(row)
    JargonEntryModel.new(id: row['id'], headword: row['headword'], pron: row['pron'].to_s, paragraphs: body(row['body']))
  end

  def section_of(row) = JargonSectionModel.new(id: row['id'], title: row['title'], paragraphs: body(row['body']))

  def body(json) = JSON.parse(json).map { |kind, text| [kind.to_sym, text] }

  def query(sql, params = [])
    @lock.synchronize do
      @db ||= open_db or return []
      @db.execute(sql, params)
    end
  rescue SQLite3::Exception => e
    BBS.log('jargon', "#{e.class}: #{e.message}")
    []
  end

  def open_db
    return nil unless File.exist?(@path)

    SQLite3::Database.new(@path, readonly: true).tap { |db| db.results_as_hash = true }
  end
end
