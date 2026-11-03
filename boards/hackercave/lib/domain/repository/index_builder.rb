# frozen_string_literal: true

require 'fileutils'
require 'sqlite3'

# Writes a new index database (the one IndexRepository reads) at a path
# from the RFC Editor's rfc-index.xml, read as a stream by IndexParser: the
# RFCs and the numbers never issued, their relations, the STD, BCP and FYI
# series, and the full-text index (FTS5 where the SQLite has it, a search
# column for LIKE where not).
class IndexBuilder
  SERIES = %w[STD BCP FYI].freeze
  MONTHS = %w[January February March April May June July August September October November December].freeze

  def initialize(path)
    @path = path
  end

  # Builds the database from +xml+. Returns the number of RFCs issued.
  # Raises what reading the file raises.
  def build(xml)
    FileUtils.rm_f(@path)
    db = SQLite3::Database.new(@path)
    fts = create_schema(db)
    n = db.transaction { File.open(xml) { |io| fill(db, io, fts) } }
    db.execute("INSERT INTO rfcs_fts (rfcs_fts) VALUES ('rebuild')") if fts
    db.execute('VACUUM')
    n
  ensure
    db.close if db && !db.closed?
  end

  private

  # The tables; true when the SQLite has FTS5.
  def create_schema(db)
    db.execute_batch(<<~SQL)
      PRAGMA journal_mode = OFF;
      PRAGMA synchronous = OFF;
      CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, authors TEXT, date TEXT, year INTEGER, pages INTEGER,
                         status TEXT, pub_status TEXT, stream TEXT, area TEXT, wg TEXT, abstract TEXT, keywords TEXT,
                         issued INTEGER, search TEXT);
      CREATE INDEX rfcs_status ON rfcs (status, number);
      CREATE INDEX rfcs_year ON rfcs (year, number);
      CREATE TABLE relations (rfc INTEGER, kind TEXT, target INTEGER);
      CREATE INDEX relations_rfc ON relations (rfc);
      CREATE TABLE series (series TEXT, number INTEGER, rfc INTEGER);
      CREATE INDEX series_kind ON series (series, number);
      CREATE INDEX series_rfc ON series (rfc);
    SQL
    db.execute("CREATE VIRTUAL TABLE rfcs_fts USING fts5(title, authors, keywords, abstract, content='rfcs', " \
               "content_rowid='number', tokenize='unicode61 remove_diacritics 2')")
    true
  rescue SQLite3::SQLException
    false
  end

  # The entries of the index read from +io+ into the tables; the number of
  # RFCs issued.
  def fill(db, io, fts)
    @fts = fts
    @statements = { rfc: db.prepare("INSERT OR REPLACE INTO rfcs VALUES (#{(['?'] * 15).join(', ')})"),
                    relation: db.prepare('INSERT INTO relations VALUES (?, ?, ?)'),
                    series: db.prepare('INSERT INTO series VALUES (?, ?, ?)') }
    n = 0
    IndexParser.each(io) { |entry| n += insert(entry) }
    n
  ensure
    @statements&.each_value(&:close)
  end

  # One entry; 1 when it is an RFC issued, else 0.
  def insert(entry)
    kind, number = doc_id(entry[:id])
    return 0 unless number

    if SERIES.include?(kind) then add_series(kind, number, entry)
    elsif entry[:kind] == 'rfc-not-issued-entry' then add_missing(number)
    else return add_rfc(number, entry)
    end
    0
  end

  def add_series(kind, number, entry)
    entry[:lists][:is_also].each do |id|
      member_kind, member = doc_id(id)
      @statements[:series].execute(kind, number, member) if member_kind == 'RFC'
    end
  end

  def add_missing(number) = @statements[:rfc].execute(number, *([nil] * 12), 0, nil)

  # The RFC and its relations; 1.
  def add_rfc(number, entry)
    @statements[:rfc].execute(*row(number, entry), @fts ? nil : search_text(entry))
    IndexRepository::RELATIONS.each_key do |kind|
      entry[:lists][kind.to_sym].each do |id|
        target_kind, target = doc_id(id)
        @statements[:relation].execute(number, kind, target) if target_kind == 'RFC'
      end
    end
    1
  end

  def row(number, entry)
    [number, entry[:title].to_s, entry[:authors].join('; '), date(entry), entry[:year].to_i, entry[:pages].to_i,
     entry[:status].to_s, entry[:pub_status].to_s, entry[:stream].to_s, entry[:area].to_s, entry[:wg].to_s,
     entry[:abstract].join("\n\n"), entry[:keywords].join('; '), 1]
  end

  # "1981-09", or "1990-04-01" when the index has the day.
  def date(entry)
    month = MONTHS.index(entry[:month].to_s)
    return entry[:year].to_s unless month

    [entry[:year], format('%02d', month + 1), (format('%02d', entry[:day].to_i) if entry[:day])].compact.join('-')
  end

  # "RFC0793" → ["RFC", 793]; nil for anything else.
  def doc_id(id)
    m = /\A(RFC|STD|BCP|FYI)0*(\d+)\z/.match(id.to_s) or return nil
    [m[1], m[2].to_i]
  end

  def search_text(entry) = [entry[:title], *entry[:authors], *entry[:keywords], *entry[:abstract]].join(' ').downcase
end
