# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the
# catalog, the Classics shelf, the reads) and the reading room (the texts,
# cut into chapters and cached), wired to Project Gutenberg. The catalog is
# kept fresh in the background: looked at every CHECK_EVERY seconds, a
# failed refresh tried again after RETRY_AFTER (doubled up to CHECK_EVERY).
class ScriptoriumBBS
  include Rubbs::Common::Board::Domain

  CHECK_EVERY = 3600
  RETRY_AFTER = 300

  setting :mirror, 'https://www.gutenberg.org'
  setting :catalog_url
  setting :catalog_ttl, 7.0
  setting :book_max, 8 * 1024 * 1024
  setting :cache_mb, 300
  path    :db, 'data/scriptorium.sqlite3'
  path    :catalog_db, 'data/catalog.sqlite3'
  path    :catalog_file, 'data/pg_catalog.csv.gz'
  path    :texts, 'data/texts'
  path    :classics, 'config/classics.yml'

  database :db, MIGRATIONS
  database :catalog_db, CATALOG_MIGRATIONS, name: :catalog

  service(:library) do
    import_legacy_reads
    LibraryService.new(
      classics:     ClassicsRepository.new(classics),
      gutenberg:    gutenberg,
      catalog_file: catalog_file,
      ttl:          catalog_ttl * 86_400
    )
  end
  service(:reading) do
    ReadingService.new(
      gutenberg: gutenberg,
      cache:     TextCacheRepository.new(texts, max_bytes: cache_mb * 1024 * 1024),
      chapters:  ChapterService.new,
      max_bytes: book_max
    )
  end

  background('catalog refresh', every: CHECK_EVERY, retry_after: RETRY_AFTER, max_retry: CHECK_EVERY) { library.refresh }

  private

  def gutenberg
    @gutenberg ||= GutenbergRepository.new(
      mirror: mirror, catalog_url: catalog_url || "#{mirror.delete_suffix('/')}/cache/epub/feeds/pg_catalog.csv.gz"
    )
  end

  # The reads.jsonl of an older board next to the database, imported once.
  def import_legacy_reads = LegacyReads.import(File.join(File.dirname(db), 'reads.jsonl'))
end
