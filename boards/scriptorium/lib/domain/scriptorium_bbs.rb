# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the
# catalog, the Classics shelf, the reads) and the reading room (the texts,
# cut into chapters and cached), wired to Project Gutenberg. Both faces
# (lib/ui/modern, lib/ui/petscii) work on one instance of it. #start keeps
# the catalog fresh in a background thread.
class ScriptoriumBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'ScriptoriumBBS/1.0 (telnet board of Teletype Games; +https://teletypegames.org)'
  # How often the refresher looks at the age of the catalog.
  CHECK_EVERY = 3600

  attr_reader :library, :reading

  def initialize
    data      = ->(name) { File.join(ROOT, 'data', name) }
    mirror    = ENV.fetch('SCRIPTORIUM_BBS_MIRROR', 'https://www.gutenberg.org')
    gutenberg = GutenbergRepository.new(
      mirror: mirror, user_agent: USER_AGENT,
      catalog_url: ENV.fetch('SCRIPTORIUM_BBS_CATALOG_URL', "#{mirror.delete_suffix('/')}/cache/epub/feeds/pg_catalog.csv.gz")
    )
    catalog  = CatalogRepository.new(ENV.fetch('SCRIPTORIUM_BBS_DB', data.call('catalog.sqlite3')))
    classics = ClassicsRepository.new(ENV.fetch('SCRIPTORIUM_BBS_CLASSICS', File.join(ROOT, 'config/classics.yml')))
    reads    = ReadRepository.new(ENV.fetch('SCRIPTORIUM_BBS_READS', data.call('reads.jsonl')))
    cache    = TextCacheRepository.new(ENV.fetch('SCRIPTORIUM_BBS_TEXTS', data.call('texts')),
                                       max_bytes: Integer(ENV.fetch('SCRIPTORIUM_BBS_CACHE_MB', '300')) * 1024 * 1024)

    @library = LibraryService.new(catalog: catalog, classics: classics, reads: reads, gutenberg: gutenberg,
                                  catalog_file: ENV.fetch('SCRIPTORIUM_BBS_CATALOG_FILE', data.call('pg_catalog.csv.gz')),
                                  ttl: Float(ENV.fetch('SCRIPTORIUM_BBS_CATALOG_TTL', '7')) * 86_400)
    @reading = ReadingService.new(gutenberg: gutenberg, cache: cache, reads: reads, chapters: ChapterService.new,
                                  max_bytes: Integer(ENV.fetch('SCRIPTORIUM_BBS_BOOK_MAX', (8 * 1024 * 1024).to_s)))
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
        warn "scriptorium: catalog refresh: #{e.class}: #{e.message}"
        sleep CHECK_EVERY
      end
    end
    self
  end
end
