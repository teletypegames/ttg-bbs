# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'sqlite3'

# Writes a new index database (the one IndexRepository reads) at a path
# from the RFC Editor's rfc-index.xml, read as a stream by IndexParser: the
# RFCs and the numbers never issued, their relations, the STD, BCP and FYI
# series, and the full-text index (FTS5 where the SQLite has it, a search
# column for LIKE where not). The errata (errata.json) and the IENs (an
# IenIndex, under negative numbers) go in too when given.
class IndexBuilder
  SERIES = %w[STD BCP FYI].freeze
  MONTHS = %w[January February March April May June July August September October November December].freeze
  # The tables, but the full-text index.
  SCHEMA = <<~SQL
    PRAGMA journal_mode = OFF;
    PRAGMA synchronous = OFF;
    CREATE TABLE rfcs (number INTEGER PRIMARY KEY, title TEXT, authors TEXT, date TEXT, year INTEGER, pages INTEGER,
                       status TEXT, pub_status TEXT, stream TEXT, area TEXT, wg TEXT, abstract TEXT, keywords TEXT,
                       formats TEXT, issued INTEGER, search TEXT);
    CREATE INDEX rfcs_status ON rfcs (status, number);
    CREATE INDEX rfcs_year ON rfcs (year, number);
    CREATE TABLE relations (rfc INTEGER, kind TEXT, target INTEGER);
    CREATE INDEX relations_rfc ON relations (rfc);
    CREATE TABLE series (series TEXT, number INTEGER, rfc INTEGER);
    CREATE INDEX series_kind ON series (series, number);
    CREATE INDEX series_rfc ON series (rfc);
    CREATE TABLE errata (id INTEGER PRIMARY KEY, rfc INTEGER, status TEXT, type TEXT, section TEXT, orig_text TEXT,
                         correct_text TEXT, notes TEXT, submitted TEXT);
    CREATE INDEX errata_rfc ON errata (rfc);
  SQL

  def initialize(path)
    @path = path
  end

  # Builds the database from +xml+, with the +errata+ (the path of
  # errata.json) and the +iens+ (an IenIndex) when given. Returns the number
  # of RFCs issued. Raises what reading the files raises.
  def build(xml, errata: nil, iens: nil)
    FileUtils.rm_f(@path)
    db = SQLite3::Database.new(@path)
    fts = create_schema(db)
    n = db.transaction { File.open(xml) { |io| fill(db, io, fts) }.tap { extras(db, errata, iens, fts) } }
    db.execute("INSERT INTO rfcs_fts (rfcs_fts) VALUES ('rebuild')") if fts
    db.execute('VACUUM')
    n
  ensure
    db.close if db && !db.closed?
  end

  private

  # The tables; true when the SQLite has FTS5.
  def create_schema(db)
    db.execute_batch(SCHEMA)
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
    @statements = { rfc: db.prepare("INSERT OR REPLACE INTO rfcs VALUES (#{(['?'] * 16).join(', ')})"),
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

  def add_missing(number) = @statements[:rfc].execute(number, *([nil] * 13), 0, nil)

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
     entry[:abstract].join("\n\n"), entry[:keywords].join('; '), entry[:formats].join(' '), 1]
  end

  def extras(db, errata, iens, fts)
    add_iens(db, iens, fts) if iens
    add_errata(db, errata) if errata
  end

  # The IENs of +iens+ under negative numbers, as Internet Experiment Notes
  # of the stream "IEN".
  def add_iens(db, iens, fts)
    insert = db.prepare("INSERT OR REPLACE INTO rfcs VALUES (#{(['?'] * 16).join(', ')})")
    iens.entries.each do |e|
      insert.execute(-e.number, e.title, e.author, e.date, e.date[0, 4].to_i, 0, '', '', 'IEN', '', '', '', '',
                     e.formats, 1, fts ? nil : "#{e.title} #{e.author}".downcase)
    end
  ensure
    insert&.close
  end

  # The errata of errata.json; the RFCs only.
  def add_errata(db, path)
    insert = db.prepare('INSERT OR REPLACE INTO errata VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
    JSON.parse(File.read(path)).each do |e|
      kind, number = doc_id(e['doc-id'])
      next unless kind == 'RFC' && (id = Integer(e['errata_id'], exception: false))

      insert.execute(id, number, *%w[errata_status_code errata_type_code section orig_text correct_text notes submit_date]
        .map { |k| errata_text(e[k]) })
    end
  ensure
    insert&.close
  end

  # A field of an erratum without control characters, its tabs as spaces.
  def errata_text(value)
    BBS::Text.clean(value.to_s, keep_newlines: true).split("\n").map { |l| DocumentModel.expand(l) }.join("\n")
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
