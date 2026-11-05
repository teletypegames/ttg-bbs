# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'ipaddr'
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
    # The ranges written at once while the file is made.
    BATCH = 1000

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
      cc = @mutex.synchronize do
        next unless open

        addr.ipv4? ? GeoipV4Model.country(addr.to_i) : GeoipV6Model.country(addr.hton)
      end
      cc == 'ZZ' ? nil : cc&.downcase
    rescue IPAddr::Error, Sequel::Error
      nil
    end

    # The month of the database in use ("2026-11"), or nil.
    def month
      @mutex.synchronize { open && GeoipMetaModel.month }
    rescue Sequel::Error
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
        Rubbs.log('geoip', "DB-IP #{m}: #{e.message}")
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
        close
        File.rename(tmp, File.join(@dir, FILE))
      end
      month
    end

    private

    # The lookup file in use, read only, its models (GeoipV4Model,
    # GeoipV6Model, GeoipMetaModel) bound to it; nil without one.
    def open
      return @db if @db
      return unless File.exist?(path)

      @db = Sequel.sqlite(path, readonly: true)
      Rubbs::Common::Storage::Model.bind(geoip: @db)
      @db
    end

    def close
      return unless @db

      @db.disconnect
      Sequel.synchronize { Sequel::DATABASES.delete(@db) }
      @db = nil
    end

    def build(path, month, gzip)
      db = Sequel.sqlite(path)
      Rubbs::Common::Storage::Database.migrate(db, GEOIP_MIGRATIONS)
      db.transaction do
        insert_ranges(db, gzip)
        GeoipMetaModel.made_of(db, month)
      end
    ensure
      db&.disconnect
      Sequel.synchronize { Sequel::DATABASES.delete(db) } if db
    end

    # The ranges of the gzipped CSV +gzip+ (an IO, read as it is inflated)
    # into the v4 and v6 tables, BATCH at a time.
    def insert_ranges(db, gzip)
      ranges = { v4: [], v6: [] }
      Zlib::GzipReader.new(gzip).each_line do |line|
        family, range = range(line)
        next unless family

        ranges[family] << range
        flush(db, ranges) if ranges[family].size >= BATCH
      end
      flush(db, ranges)
    end

    def flush(db, ranges)
      GeoipV4Model.add(db, ranges[:v4]) if ranges[:v4].any?
      GeoipV6Model.add(db, ranges[:v6]) if ranges[:v6].any?
      ranges.each_value(&:clear)
    end

    # The family (:v4 or :v6) and [start, stop, cc] of a "start,stop,cc"
    # line; nil for a line without a country or with a broken address.
    def range(line)
      start, stop, cc = line.chomp.split(',', 3)
      return unless cc&.match?(/\A[A-Z]{2}\z/)

      from = IPAddr.new(start)
      to   = IPAddr.new(stop)
      from.ipv4? ? [:v4, [from.to_i, to.to_i, cc]] : [:v6, [from.hton, to.hton, cc]]
    rescue IPAddr::Error
      nil
    end
  end
end
