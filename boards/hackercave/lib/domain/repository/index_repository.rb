# frozen_string_literal: true

require 'fileutils'
require 'sqlite3'

# The RFC Editor's index in SQLite (data/index.sqlite3): the RFCs (the
# numbers never issued too) and the Internet Experiment Notes (IENs, under
# negative numbers: IEN 137 is -137, see RfcModel#ien?), how the RFCs are
# related (obsoletes, updates, see also), the STD, BCP and FYI series, the
# errata (IndexErrata), the shelves (IndexShelves), and a full-text index of the titles,
# authors, keywords and abstracts (FTS5; an indexed LIKE where the SQLite has
# no FTS5). Nothing of it is held in Ruby: every list is a query. #import
# builds a new database from rfc-index.xml next to the old one (IndexBuilder)
# and swaps it in, so callers read the old index meanwhile. One read-only connection
# behind a Mutex.
class IndexRepository
  include IndexShelves
  include IndexErrata

  COLUMNS = 'number, title, authors, date, pages, status, pub_status, stream, area, wg, abstract, keywords, formats, ' \
            'issued'
  # The same, of the rfcs table under the name r.
  R_COLUMNS = COLUMNS.split(', ').map { |c| "r.#{c}" }.join(', ')
  # The relations of an RFC to others, and what each reads as.
  RELATIONS = { 'obsoleted_by' => 'obsoleted by', 'obsoletes' => 'obsoletes', 'updated_by' => 'updated by',
                'updates' => 'updates', 'see_also' => 'see also' }.freeze

  def initialize(path)
    @path  = path
    @lock  = Mutex.new
    @db    = nil
    @fts   = false
    @count = nil
    open_db if File.exist?(path)
  end

  def ready? = @lock.synchronize { !@db.nil? }

  # When the index was last imported, or nil.
  def imported_at = File.exist?(@path) ? File.mtime(@path) : nil

  # The number of RFCs issued (IENs not counted), counted when the index was
  # opened.
  def count = @count || 0

  # The RFC of +number+ (issued or not), or nil.
  def rfc(number)
    row = query("SELECT #{COLUMNS} FROM rfcs WHERE number = ?", [Integer(number)]).first
    row && RfcModel.from_row(row)
  rescue ArgumentError, TypeError
    nil
  end

  # The issued RFCs of +numbers+ in the order given.
  def rfcs(numbers)
    numbers = numbers.map(&:to_i)
    return [] if numbers.empty?

    by_number = query("SELECT #{COLUMNS} FROM rfcs WHERE issued = 1 AND number IN (#{(['?'] * numbers.size).join(',')})",
                      numbers).to_h { |r| [r['number'], RfcModel.from_row(r)] }
    numbers.filter_map { |n| by_number[n] }
  end

  # At most +limit+ RFCs whose title, authors, keywords or abstract have
  # every word of +words+ (as a word prefix), best matches first; +status+
  # and +year+ narrow them.
  def search(words, status: nil, year: nil, limit: 100)
    filters = { 'r.status = ?' => status, 'r.year = ?' => year }.compact
    sql = filters.keys.map { |f| " AND #{f}" }.join
    rows = if words.empty? then filtered(sql, filters.values, limit)
           elsif @fts then match(words, sql, filters.values, limit)
           else like(words, sql, filters.values, limit)
           end
    rows.map { |r| RfcModel.from_row(r) }
  end

  # The RFCs related to +number+ as [relation, RfcModel], in the order of
  # RELATIONS, each kind by number.
  def relations(number)
    rows = query("SELECT l.kind, #{R_COLUMNS} FROM relations l JOIN rfcs r ON r.number = l.target " \
                 'WHERE l.rfc = ? ORDER BY l.kind, r.number', [Integer(number)])
    rows.sort_by { |r| [RELATIONS.keys.index(r['kind']), r['number']] }
        .map { |r| [RELATIONS.fetch(r['kind']), RfcModel.from_row(r)] }
  end

  # The series +number+ is part of: ["STD 7"].
  def series_of(number)
    query('SELECT series, number FROM series WHERE rfc = ? ORDER BY series, number', [Integer(number)])
      .map { |r| "#{r['series']} #{r['number']}" }
  end

  # The RFCs of a series (+kind+ STD, BCP or FYI) as [label, RfcModel]:
  # ["STD 7", RFC 9293], by series number.
  def series(kind)
    query("SELECT s.number AS series_number, #{R_COLUMNS} FROM series s JOIN rfcs r ON r.number = s.rfc " \
          'WHERE s.series = ? ORDER BY s.number, r.number', [kind])
      .map { |r| ["#{kind} #{r['series_number']}", RfcModel.from_row(r)] }
  end

  # The members of series +kind+ +number+ ("STD", 7).
  def series_members(kind, number)
    query("SELECT #{R_COLUMNS} FROM series s JOIN rfcs r ON r.number = s.rfc WHERE s.series = ? AND s.number = ? " \
          'ORDER BY r.number', [kind, Integer(number)]).map { |r| RfcModel.from_row(r) }
  end

  # Builds the index from +xml+ (rfc-index.xml) and swaps it in; +errata+
  # (errata.json) and +iens+ (an IenIndex) go in too when given. Returns the
  # number of RFCs issued. Raises what reading the files raises; the old
  # index stays then.
  def import(xml, errata: nil, iens: nil)
    tmp = "#{@path}.new"
    n = IndexBuilder.new(tmp).build(xml, errata: errata, iens: iens)
    swap(tmp)
    n
  ensure
    FileUtils.rm_f(tmp) if tmp
  end

  private

  def filtered(sql, params, limit)
    query("SELECT #{R_COLUMNS} FROM rfcs r WHERE r.issued = 1#{sql} ORDER BY r.number DESC LIMIT ?", [*params, limit])
  end

  # The full-text search: every word a prefix, best matches first.
  def match(words, sql, params, limit)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    query("SELECT #{R_COLUMNS} FROM rfcs_fts f JOIN rfcs r ON r.number = f.rowid WHERE rfcs_fts MATCH ?#{sql} " \
          'ORDER BY bm25(rfcs_fts, 10.0, 4.0, 6.0, 1.0), r.number DESC LIMIT ?', [terms, *params, limit])
  end

  # The search of an SQLite without FTS5: every word somewhere.
  def like(words, sql, params, limit)
    likes = words.map { ' AND r.search LIKE ?' }.join
    query("SELECT #{R_COLUMNS} FROM rfcs r WHERE r.issued = 1#{likes}#{sql} ORDER BY r.number DESC LIMIT ?",
          [*words.map { |w| "%#{w.downcase}%" }, *params, limit])
  end

  def swap(tmp)
    @lock.synchronize do
      @db&.close
      File.rename(tmp, @path)
      @db = nil
      open_db
    end
  end

  # Opens the database; one of an older board (without the formats or the
  # errata) is not opened, so the next refresh imports it anew.
  def open_db
    db = SQLite3::Database.new(@path, readonly: true)
    db.results_as_hash = true
    db.busy_timeout = 5000
    db.execute('PRAGMA cache_size = -2000')
    db.execute('SELECT formats FROM rfcs, errata LIMIT 0')
    @fts   = !db.execute("SELECT 1 FROM sqlite_master WHERE name = 'rfcs_fts'").empty?
    @count = db.execute('SELECT COUNT(*) AS n FROM rfcs WHERE issued = 1 AND number > 0').first['n']
    @db    = db
  rescue SQLite3::Exception => e
    BBS.log('index', "#{@path}: #{e.class}: #{e.message}")
    @db = nil
  end

  def query(sql, params = [])
    @lock.synchronize do
      return [] unless @db

      @db.execute(sql, params)
    end
  rescue SQLite3::Exception => e
    BBS.log('index', "#{e.class}: #{e.message}")
    []
  end
end
