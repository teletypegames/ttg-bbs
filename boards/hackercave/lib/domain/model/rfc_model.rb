# frozen_string_literal: true

require 'date'

# One RFC of the RFC Editor's index: a row of the rfcs table of
# data/index.sqlite3 (Schema::Index). +authors+ and +keywords+ are joined
# with "; ", +date+ is "1981-09" or "1990-04-01", +abstract+ has its
# paragraphs separated by an empty line, +formats+ is what the RFC Editor
# has of it ("TXT HTML PDF"). A number that was never issued has +issued+ 0
# and nothing else. An Internet Experiment Note (1977-1982) is in the same
# table under a negative number: IEN 137 is -137 (#ien?).
#
# The class methods are the index's queries: an RFC, the search, the
# shelves (the statuses, the decades, the newest, the RFCs of a month and
# the IENs; the IENs are on their own shelf only). Until the first import
# the table is empty and they find nothing.
class RfcModel < BBS::Model
  table :rfcs, database: :index

  # The columns an RfcModel is read with.
  COLUMNS = %i[number title authors date pages status pub_status stream area wg abstract keywords formats issued].freeze
  # The columns a row is written with (IndexBuilder), in the table's order.
  ROW = %i[number title authors date year pages status pub_status stream area wg abstract keywords formats issued
           search].freeze
  TEXTS = %i[title authors date status pub_status stream area wg abstract keywords formats].freeze

  TEXTS.each { |column| define_method(column) { self[column].to_s } }

  def number = self[:number]

  def pages = self[:pages].to_i

  # An RFC known only by its number and title (config/shelves.yml), while
  # the index is not there yet.
  def self.stub(number, title = '')
    load(number: number, title: title, authors: '', date: '', pages: 0, status: '', pub_status: '', stream: '',
         area: '', wg: '', abstract: '', keywords: '', formats: 'TXT', issued: 1)
  end

  # The status as it is read: "Internet Standard", "Best Current Practice".
  def self.status_label(status) = status.split.map(&:capitalize).join(' ')

  # Whether the index was imported: it has RFCs.
  def self.ready? = guard(false) { !dataset.empty? }

  # When the index was last imported (its file last written), or nil.
  def self.imported_at
    path = db.opts[:database].to_s
    ready? && File.exist?(path) ? File.mtime(path) : nil
  end

  # The number of RFCs issued (IENs not counted), counted once an index.
  def self.issued_count
    counts.fetch(db) do
      n = guard(0) { shelf.count }
      n.positive? ? (counts[db] = n) : n
    end
  end

  def self.counts = @counts ||= {}

  private_class_method :counts

  # The RFC of +number+ (issued or not), or nil.
  def self.rfc(number)
    guard(nil) { select(*COLUMNS).where(number: Integer(number)).first }
  rescue ArgumentError, TypeError
    nil
  end

  # The issued RFCs of +numbers+ in the order given.
  def self.rfcs(numbers)
    numbers = numbers.map(&:to_i)
    return [] if numbers.empty?

    by_number = guard([]) { select(*COLUMNS).where(issued: 1, number: numbers).all }.to_h { |r| [r.number, r] }
    numbers.filter_map { |n| by_number[n] }
  end

  # At most +limit+ RFCs whose title, authors, keywords or abstract have
  # every word of +words+ (as a word prefix), best matches first; +status+
  # and +year+ narrow them.
  def self.search(words, status: nil, year: nil, limit: 100)
    found = select(*COLUMNS.map { |c| Sequel[:rfcs][c] }).where(Sequel[:rfcs][:issued] => 1)
    filters = { Sequel[:rfcs][:status] => status, Sequel[:rfcs][:year] => year }.compact
    found = found.where(filters) unless filters.empty?
    guard([]) do
      if words.empty? then found.reverse(Sequel[:rfcs][:number])
      elsif fts? then match(found, words)
      else like(found, words)
      end.limit(limit).all
    end
  end

  # Empties the index and runs the block, which fills it (IndexBuilder),
  # given whether the full-text index is FTS5; the full-text index is built
  # after it. All in one transaction: callers read the old index meanwhile,
  # and it stays when the block raises. Returns the block's value.
  def self.rebuild
    value = db.transaction do
      fts = Schema::Index.create(db)
      yield(fts).tap { db.run("INSERT INTO rfcs_fts (rfcs_fts) VALUES ('rebuild')") if fts }
    end
    counts.delete(db)
    db.run('PRAGMA wal_checkpoint(TRUNCATE)')
    value
  end

  # Writes +rows+ (values in the order of ROW), a row of the same number
  # replaced.
  def self.insert_rows(rows) = dataset.insert_conflict(:replace).import(ROW, rows)

  # The issued RFCs, the IENs not.
  def self.shelf = select(*COLUMNS).where(issued: 1, number: 1..)

  # The value of the block, or +fallback+ when the database fails (logged).
  def self.guard(fallback)
    yield
  rescue Sequel::DatabaseError => e
    BBS.log('index', "#{e.class}: #{e.message}")
    fallback
  end

  # Whether the full-text index is FTS5.
  def self.fts? = !db[:sqlite_master].where(name: 'rfcs_fts').empty?

  # The full-text search of +found+: every word a prefix, best matches first.
  def self.match(found, words)
    terms = words.map { |w| %("#{w.delete('"')}"*) }.join(' ')
    found.join(:rfcs_fts, rowid: :number).where(Sequel.lit('rfcs_fts MATCH ?', terms))
         .order(Sequel.function(:bm25, :rfcs_fts, 10.0, 4.0, 6.0, 1.0), Sequel.desc(Sequel[:rfcs][:number]))
  end

  # The search of an SQLite without FTS5: every word somewhere.
  def self.like(found, words)
    words.reduce(found) { |ds, w| ds.where(Sequel.like(Sequel[:rfcs][:search], "%#{w.downcase}%")) }
         .reverse(Sequel[:rfcs][:number])
  end

  private_class_method :match, :like

  # How many RFCs there are of each status, the most first: [[status, n]].
  def self.statuses = guard([]) { shelf.unordered.group_and_count(:status).reverse(:count).map { |r| [r[:status], r[:count]] } }

  # The RFCs of +status+, the newest first.
  def self.with_status(status, limit:) = guard([]) { shelf.where(status: status).reverse(:number).limit(limit).all }

  # How many RFCs each decade has: [[1960, 1], [1970, 700], …].
  def self.decades
    decade = Sequel.lit('(year / 10) * 10')
    guard([]) do
      shelf.unordered.group_and_count(decade.as(:decade)).order(:decade).map { |r| [r[:decade], r[:count]] }
    end
  end

  # The RFCs of the ten years from +decade+, by number.
  def self.of_decade(decade, limit:) = guard([]) { shelf.where(year: decade..(decade + 9)).order(:number).limit(limit).all }

  # The +n+ RFCs of the highest numbers.
  def self.newest(n) = guard([]) { shelf.reverse(:number).limit(n).all }

  # The RFCs published in +month+ (1-12) of any year, the oldest first.
  def self.of_month(month, limit:) = guard([]) { in_month(month).order(:date, :number).limit(limit).all }

  # How many RFCs were published in +month+ of any year.
  def self.month_count(month) = guard(0) { in_month(month).count }

  # The IENs, by number.
  def self.iens = guard([]) { select(*COLUMNS).where(number: ..-1).reverse(:number).all }

  def self.in_month(month) = shelf.where(Sequel.function(:substr, :date, 6, 2) => format('%02d', month))

  private_class_method :in_month

  def issued? = [true, 1].include?(self[:issued])

  alias issued issued?

  # Whether this is an Internet Experiment Note, not an RFC.
  def ien? = number.negative?

  # Its number in its own series: 137 for IEN 137.
  def serial = number.abs

  # Whether the RFC Editor has it as plain text.
  def text? = formats.split.include?('TXT')

  def name = "#{ien? ? 'IEN' : 'RFC'} #{serial}"

  def author_list = authors.split('; ').reject(&:empty?)

  def keyword_list = keywords.split('; ').reject(&:empty?)

  def year = date[0, 4].to_s

  # "September 1981", "1 April 1990".
  def date_label
    year, month, day = date.split('-')
    return '' unless year

    [day&.to_i, month && Date::MONTHNAMES[month.to_i], year].compact.join(' ')
  end

  def status_label = self.class.status_label(status)

  def url
    return "rfc-editor.org/ien/ien#{serial}.#{text? ? 'txt' : 'pdf'}" if ien?

    "rfc-editor.org/rfc/rfc#{number}"
  end

  # The RFC's page at the RFC Editor (an IEN's file), the address of its QR
  # code.
  def link = "https://www.#{url}"
end
