# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'zlib'

# The catalog snapshot: a gzipped JSON file of game records from Wikidata.
# The seed ships with the image (config/catalog.json.gz); a refresh writes
# the newer one into data/. Of the two the newer is read at start. The
# games are held in memory as one frozen snapshot, swapped whole under a
# mutex when a refresh lands.
class CatalogRepository
  Snapshot = Data.define(:games, :generated_at)

  SOURCE  = 'Wikidata, https://www.wikidata.org (CC0 1.0)'
  LICENSE = 'CC0-1.0'

  def initialize(seed:, path:)
    @seed = seed
    @path = path
    @lock = Mutex.new
    @snapshot = [read(@path), read(@seed)].compact.max_by(&:generated_at) || Snapshot.new(games: [].freeze,
                                                                                          generated_at: Time.at(0))
  end

  def snapshot = @lock.synchronize { @snapshot }

  # Writes +records+ as the new snapshot in data/ and swaps it in. Raises
  # (SystemCallError, IOError) when the file could not be written; the old
  # snapshot stays.
  def replace(records, at: Time.now.utc)
    self.class.write(@path, records, at)
    fresh = Snapshot.new(games: games_of(records), generated_at: at)
    @lock.synchronize { @snapshot = fresh }
  end

  # Writes a catalog file atomically (bin/refresh-catalog writes the seed).
  def self.write(path, records, at)
    FileUtils.mkdir_p(File.dirname(path))
    tmp = "#{path}.tmp"
    Zlib::GzipWriter.open(tmp, Zlib::BEST_COMPRESSION) do |gz|
      gz.write(JSON.generate({ 'source' => SOURCE, 'license' => LICENSE, 'generated' => at.utc.iso8601,
                               'games' => records }))
    end
    File.rename(tmp, path)
  end

  private

  def read(path)
    return nil unless File.exist?(path)

    data = JSON.parse(Zlib::GzipReader.open(path, &:read))
    Snapshot.new(games: games_of(data['games']), generated_at: Time.iso8601(data['generated']))
  rescue StandardError => e
    BBS.log('catalog', "reading #{path}: #{e.class}: #{e.message}")
    nil
  end

  def games_of(records)
    names = {}
    Array(records).filter_map { |r| GameModel.from_record(r, names) }.freeze
  end
end
