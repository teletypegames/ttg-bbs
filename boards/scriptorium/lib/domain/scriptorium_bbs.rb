# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the
# catalog, the Classics shelf, the reads) and the reading room (the texts,
# cut into chapters and cached), wired to Project Gutenberg. The catalog is
# kept fresh in the background: looked at every CHECK_EVERY seconds, a
# failed refresh tried again after RETRY_AFTER (doubled up to CHECK_EVERY).
class ScriptoriumBBS
  include BBS::Domain

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

  service(:library) do
    LibraryService.new(catalog: CatalogRepository.new(catalog_db), classics: ClassicsRepository.new(classics),
                       reads: reads, gutenberg: gutenberg, catalog_file: catalog_file, ttl: catalog_ttl * 86_400)
  end
  service(:reading) do
    ReadingService.new(gutenberg: gutenberg, cache: TextCacheRepository.new(texts, max_bytes: cache_mb * 1024 * 1024),
                       reads: reads, chapters: ChapterService.new, max_bytes: book_max)
  end

  background('catalog refresh', every: CHECK_EVERY, retry_after: RETRY_AFTER, max_retry: CHECK_EVERY) { library.refresh }

  private

  def gutenberg
    @gutenberg ||= GutenbergRepository.new(
      mirror: mirror, catalog_url: catalog_url || "#{mirror.delete_suffix('/')}/cache/epub/feeds/pg_catalog.csv.gz"
    )
  end

  # The reads in the board's database, with the reads.jsonl of an older
  # board next to it imported once.
  def reads
    @reads ||= begin
      database = database(db, *ReadRepository::MIGRATIONS)
      ReadRepository.new(database).tap do |reads|
        LegacyReads.import(File.join(File.dirname(db), 'reads.jsonl'), db: database, reads: reads)
      end
    end
  end
end
