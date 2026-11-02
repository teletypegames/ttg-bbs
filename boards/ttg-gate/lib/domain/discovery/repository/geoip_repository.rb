# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'ipaddr'
require 'sqlite3'
require 'zlib'

module Discovery
  # The country of an IP address from DB-IP's free "IP to Country Lite"
  # database (CC BY 4.0, https://db-ip.com), our own copy (D9): the monthly
  # CSV is downloaded into data/geoip/ and turned into a small SQLite file of
  # ranges, so a lookup is one indexed query and the prober keeps no table in
  # memory. #refresh fetches a new month once it is out; until then, and when
  # a download fails, the old file serves.
  class GeoipRepository
    URL = 'https://download.db-ip.com/free/dbip-country-lite-%<month>s.csv.gz'
    FILE = 'dbip-country-lite.sqlite3'
    # The wait after a failed download before the next try.
    RETRY = 6 * 3600

    def initialize(dir, fetcher: SourceFetcher.new)
      @dir     = dir
      @fetcher = fetcher
      @mutex   = Mutex.new
      @db      = nil
      @tried   = nil
    end

    # The lookup file in use.
    def path = File.join(@dir, FILE)

    # The ISO country code of +ip+ (lowercase), or nil.
    def country(ip)
      return unless ip

      addr = IPAddr.new(ip)
      table, key = addr.ipv4? ? ['v4', addr.to_i] : ['v6', SQLite3::Blob.new(addr.hton)]
      @mutex.synchronize do
        db = open
        return unless db

        row = db.get_first_row("SELECT stop, cc FROM #{table} WHERE start <= ? ORDER BY start DESC LIMIT 1", [key])
        return unless row && (addr.ipv4? ? row[0] >= key : row[0].b >= key.b)

        row[1] == 'ZZ' ? nil : row[1].downcase
      end
    rescue IPAddr::Error, SQLite3::Exception
      nil
    end

    # The month of the database in use ("2026-11"), or nil.
    def month
      @mutex.synchronize { open&.get_first_value("SELECT value FROM meta WHERE key = 'month'") }
    rescue SQLite3::Exception
      nil
    end

    # Downloads the database of +now+'s month when it is not the one in use
    # (the previous month's when the new one is not out yet). Returns the
    # month in use.
    def refresh(now = Time.now.utc)
      current = month
      wanted  = now.strftime('%Y-%m')
      return current if current == wanted
      return current if @tried && now.to_i - @tried < RETRY

      @tried = now.to_i
      [wanted, (now.to_date << 1).strftime('%Y-%m')].each do |m|
        next if m == current

        return @fetcher.download(URI(format(URL, month: m))) { |file| install(m, file) }
      rescue SourceFetcher::FetchError => e
        BBS.log('geoip', "DB-IP #{m}: #{e.message}")
      end
      current
    end

    # Builds the lookup file from +gzip+, an IO of the gzipped CSV of
    # +month+, and swaps it in. Returns the month.
    def install(month, gzip)
      FileUtils.mkdir_p(@dir)
      tmp = File.join(@dir, "#{FILE}.new")
      FileUtils.rm_f(tmp)
      build(tmp, month, gzip)
      @mutex.synchronize do
        @db&.close
        @db = nil
        File.rename(tmp, File.join(@dir, FILE))
      end
      month
    end

    private

    def open
      return @db if @db

      path = File.join(@dir, FILE)
      @db = SQLite3::Database.new(path, readonly: true) if File.exist?(path)
    end

    def build(path, month, gzip)
      db = SQLite3::Database.new(path)
      db.execute_batch(<<~SQL)
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE v4 (start INTEGER PRIMARY KEY, stop INTEGER NOT NULL, cc TEXT NOT NULL);
        CREATE TABLE v6 (start BLOB PRIMARY KEY, stop BLOB NOT NULL, cc TEXT NOT NULL) WITHOUT ROWID;
      SQL
      db.transaction do
        insert_ranges(db, gzip)
        db.execute('INSERT INTO meta VALUES (?, ?)', ['month', month])
      end
      db.close
    end

    # The ranges of the gzipped CSV +gzip+ (an IO, read as it is inflated)
    # into the v4 and v6 tables.
    def insert_ranges(db, gzip)
      tables = { v4: db.prepare('INSERT OR REPLACE INTO v4 VALUES (?, ?, ?)'),
                 v6: db.prepare('INSERT OR REPLACE INTO v6 VALUES (?, ?, ?)') }
      Zlib::GzipReader.new(gzip).each_line { |line| insert_range(tables, line) }
    ensure
      tables&.each_value(&:close)
    end

    # One "start,stop,cc" line into its table; a line without a country or
    # with a broken address is left out.
    def insert_range(tables, line)
      start, stop, cc = line.chomp.split(',', 3)
      return unless cc&.match?(/\A[A-Z]{2}\z/)

      from = IPAddr.new(start)
      to   = IPAddr.new(stop)
      if from.ipv4? then tables[:v4].execute(from.to_i, to.to_i, cc)
      else tables[:v6].execute(SQLite3::Blob.new(from.hton), SQLite3::Blob.new(to.hton), cc)
      end
    rescue IPAddr::Error
      nil
    end
  end
end
