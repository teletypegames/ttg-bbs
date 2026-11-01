# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the
# catalog, the Classics shelf, the reads) and the reading room (the texts,
# cut into chapters and cached), wired to Project Gutenberg. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it. The only
# place that reads the environment. #start keeps the catalog fresh in a
# background thread.
class ScriptoriumBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'ScriptoriumBBS/1.0 (telnet board of Teletype Games; +https://teletypegames.org)'
  # How often the refresher looks at the age of the catalog.
  CHECK_EVERY = 3600

  attr_reader :library, :reading

  def initialize(env = ENV)
    @env      = env
    gutenberg = gutenberg_repository
    reads     = read_repository
    @library  = library_service(gutenberg, reads)
    @reading  = ReadingService.new(gutenberg: gutenberg, cache: text_cache, reads: reads, chapters: ChapterService.new,
                                   max_bytes: Integer(setting('BOOK_MAX', (8 * 1024 * 1024).to_s)))
  end

  # The services by name.
  def services = { library: @library, reading: @reading }

  # Starts the thread that imports the catalog now when there is none (or
  # it is stale) and looks again every CHECK_EVERY seconds.
  def start
    Thread.new do
      loop do
        @library.refresh
        sleep CHECK_EVERY
      rescue StandardError => e
        warn "scriptorium-bbs: catalog refresh: #{e.class}: #{e.message}"
        sleep CHECK_EVERY
      end
    end
    self
  end

  private

  def setting(name, default) = @env.fetch("SCRIPTORIUM_BBS_#{name}", default)

  def data(name) = File.join(ROOT, 'data', name)

  def gutenberg_repository
    mirror = setting('MIRROR', 'https://www.gutenberg.org')
    GutenbergRepository.new(mirror: mirror, user_agent: USER_AGENT,
                            catalog_url: setting('CATALOG_URL',
                                                 "#{mirror.delete_suffix('/')}/cache/epub/feeds/pg_catalog.csv.gz"))
  end

  # The reads in data/scriptorium.sqlite3, with the reads.jsonl of an
  # older board next to it imported once.
  def read_repository
    db = BBS::SQLite.new(setting('DB', data('scriptorium.sqlite3')))
    db.migrate(*ReadRepository::MIGRATIONS)
    reads = ReadRepository.new(db)
    LegacyReads.import(File.join(File.dirname(db.path), 'reads.jsonl'), db: db, reads: reads)
    reads
  end

  def text_cache
    TextCacheRepository.new(setting('TEXTS', data('texts')),
                            max_bytes: Integer(setting('CACHE_MB', '300')) * 1024 * 1024)
  end

  def library_service(gutenberg, reads)
    LibraryService.new(catalog: CatalogRepository.new(setting('CATALOG_DB', data('catalog.sqlite3'))),
                       classics: ClassicsRepository.new(setting('CLASSICS', File.join(ROOT, 'config/classics.yml'))),
                       reads: reads, gutenberg: gutenberg,
                       catalog_file: setting('CATALOG_FILE', data('pg_catalog.csv.gz')),
                       ttl: Float(setting('CATALOG_TTL', '7')) * 86_400)
  end
end
