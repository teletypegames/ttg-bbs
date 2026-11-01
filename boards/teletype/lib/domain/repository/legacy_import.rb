# frozen_string_literal: true

require 'csv'
require 'time'

# The files of earlier versions, brought into the database once: on the
# first start each one whose table is still empty is read row by row (a row
# that does not parse, such as the half line a killed write left behind,
# is skipped and counted, the rest still come in), inserted in one
# transaction and renamed to <file>.imported. One log line tells the counts.
class LegacyImport
  Source = Struct.new(:files, :table, :header, :row, keyword_init: true)

  SOURCES = [
    Source.new(files: ['accounts.csv'], table: 'accounts', header: true, row: :account),
    Source.new(files: ['boards/*.csv'], table: 'posts', row: :post),
    Source.new(files: ['last_read.csv'], table: 'last_read', row: :last_read),
    Source.new(files: ['last_callers.csv'], table: 'calls', row: :call),
    Source.new(files: ['oneliners.csv'], table: 'oneliners', row: :oneliner),
    Source.new(files: ['profiles.csv'], table: 'profiles', header: true, row: :profile),
    Source.new(files: ['trivia_scores.csv'], table: 'trivia_scores', row: :trivia_score),
    Source.new(files: ['votes.csv'], table: 'votes', row: :vote),
    Source.new(files: ['mail.csv'], table: 'mail', header: true, row: :letter)
  ].freeze

  # The profiles kept by BBS::Store (rubbs 0.33 turned profiles.csv into it).
  PROFILE_STORE = 'profiles.sqlite3'
  # The most lines one CSV row may span (a post or a letter of many lines).
  ROW_LINES = 60
  ISO_TIME  = /\A\d{4}-\d\d-\d\dT\d\d:\d\d/
  POST_TIME = /\A\d\d-\d\d \d\d:\d\d\z/

  def initialize(db, dir, log: ->(line) { warn line })
    @db  = db
    @dir = dir
    @log = log
  end

  # Imports what there is; returns {table => [rows imported, rows skipped]}.
  def run
    counts = SOURCES.to_h { |source| [source.table, import(source)] }
    counts['profiles'] ||= import_profile_store
    counts.compact!
    @log.call("teletype-bbs: imported into #{@db.path}: #{summary(counts)}") unless counts.empty?
    counts
  end

  # The rows of a CSV text (Arrays of String), and how many lines could
  # not be read as a row.
  def self.csv_rows(text)
    lines = text.lines
    rows  = []
    skipped = 0
    index = 0
    while index < lines.size
      row, used = parse_row(lines, index)
      row ? rows << row : skipped += 1
      index += used || 1
    end
    [rows.reject { |r| r.compact.empty? }, skipped]
  end

  # The row starting at +lines+[+index+] and the lines it takes, or nil.
  def self.parse_row(lines, index)
    buffer = +''
    lines[index, ROW_LINES].each_with_index do |line, taken|
      buffer << line
      begin
        return [CSV.parse_line(buffer) || [], taken + 1]
      rescue CSV::MalformedCSVError
        next
      end
    end
    nil
  end

  private

  def import(source)
    paths = source.files.flat_map { |pattern| Dir.glob(File.join(@dir, pattern)) }.sort
    return if paths.empty?
    return warn_kept(paths, source.table) unless empty?(source.table)

    counts = @db.transaction { paths.map { |path| import_file(path, source) } }
    paths.each { |path| File.rename(path, "#{path}.imported") }
    counts.transpose.map(&:sum)
  end

  def import_file(path, source)
    rows, unreadable = self.class.csv_rows(BBS::Text.utf8(File.binread(path)))
    rows = with_header(rows) if source.header
    records = rows.map { |row| send(source.row, row, File.basename(path, '.csv')) }
    records.compact.each { |record| insert(source.table, record) }
    [records.compact.size, unreadable + records.count(nil)]
  end

  def with_header(rows)
    header = rows.shift || []
    rows.map { |row| header.zip(row).to_h }
  end

  def import_profile_store
    path = File.join(@dir, PROFILE_STORE)
    return unless File.exist?(path) && empty?('profiles')

    records = store_rows(path).filter_map { |row| profile(row) }
    @db.transaction { records.each { |record| insert('profiles', record) } }
    File.rename(path, "#{path}.imported")
    [records.size, 0]
  end

  def store_rows(path)
    store = BBS::SQLite.new(path)
    return [] unless store.get("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'store'")

    store.query('SELECT * FROM store ORDER BY rowid')
  ensure
    store&.close
  end

  def empty?(table) = @db.get("SELECT 1 FROM #{table} LIMIT 1").nil?

  def warn_kept(paths, table)
    @log.call("teletype-bbs: #{paths.join(', ')} not imported: the #{table} table has rows already")
    nil
  end

  def insert(table, record)
    values = record.values.map { |v| v.is_a?(String) ? BBS::Text.clean(v) : v }
    marks  = (['?'] * record.size).join(', ')
    @db.query("INSERT OR REPLACE INTO #{table} (#{record.keys.join(', ')}) VALUES (#{marks})", *values)
  end

  def summary(counts)
    counts.map do |table, (rows, skipped)|
      "#{table} #{rows}#{" (#{skipped} unreadable skipped)" if skipped.positive?}"
    end.join(', ')
  end

  # ── one row of each file, or nil when it is not one ──────────────────

  def account(row, _file)
    name = row['name'].to_s
    return unless !name.empty? && row['salt'].to_s.match?(/\A\h{32}\z/) && row['digest'].to_s.match?(/\A\h{64}\z/)

    { name_key: Names.key(name), name: name, skeleton: Names.skeleton(name), salt: row['salt'],
      digest: row['digest'], created_at: row['created_at'] || Time.now.iso8601 }
  end

  def post(row, board)
    timestamp, username, text = row
    return unless row.size == 3 && timestamp.to_s.match?(POST_TIME) && username && text

    { board: board, timestamp: timestamp, username: username, user_key: Names.key(username), text: text }
  end

  def last_read(row, _file)
    name, board, count = row
    return unless row.size == 3 && name && board && count.to_s.match?(/\A\d+\z/)

    { user_key: Names.key(name), board: board, count: count.to_i }
  end

  def call(row, _file)
    timestamp, username, session_id, seconds = row
    return unless row.size.between?(3, 4) && timestamp.to_s.match?(ISO_TIME) && username
    return if seconds && !seconds.match?(/\A\d+\z/)

    { timestamp: timestamp, username: username, user_key: Names.key(username), session_id: session_id,
      seconds: seconds&.to_i }
  end

  def oneliner(row, _file)
    timestamp, username, text = row
    return unless row.size == 3 && timestamp.to_s.match?(ISO_TIME) && username && text

    { timestamp: timestamp, username: username, text: text }
  end

  def profile(row, _file = nil)
    name = row['username'].to_s
    return if name.empty?

    { user_key: Names.key(name), username: name, signature: row['signature'], location: row['location'],
      homepage: row['homepage'], notes: row['notes'], art: row['art'],
      updated_at: row['timestamp'] || Time.now.utc.iso8601 }
  end

  def trivia_score(row, _file)
    timestamp, username, points, correct = row
    return unless row.size == 4 && timestamp.to_s.match?(ISO_TIME) && username
    return unless points.to_s.match?(/\A-?\d+\z/) && correct.to_s.match?(/\A\d+\z/)

    { timestamp: timestamp, username: username, user_key: Names.key(username), points: points.to_i,
      correct: correct.to_i }
  end

  def vote(row, _file)
    poll, name, option, timestamp = row
    return unless row.size.between?(3, 4) && poll && name && option

    { poll: poll, user_key: Names.key(name), option: option, timestamp: timestamp || Time.now.iso8601 }
  end

  def letter(row, _file)
    return unless row['id'] && row['from'] && row['to'] && row['timestamp'].to_s.match?(ISO_TIME)

    { id: row['id'], timestamp: row['timestamp'], sender: row['from'], recipient: row['to'],
      recipient_key: Names.key(row['to']), subject: row['subject'].to_s, body: row['body'].to_s,
      read: row['read'] == '1' ? 1 : 0 }
  end
end
