# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the index
# of the RFC Editor, the board's own shelves, the reads) and the reading
# room (the texts, fetched once and kept on the disk), wired to
# rfc-editor.org. Both faces (lib/ui/modern, lib/ui/petscii) work on one
# instance of it. The only place that reads the environment. #start keeps
# the index fresh in a BBS.background thread.
class HackerCaveBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'HackerCaveBBS/1.0 (telnet board of Teletype Games; +https://teletypegames.org)'
  # How often the refresher looks at the age of the index, in seconds.
  CHECK_EVERY = 3600
  # Seconds before a failed refresh is tried again (doubled up to
  # CHECK_EVERY).
  RETRY_AFTER = 300

  attr_reader :library, :reading

  def initialize(env = ENV)
    @env     = env
    editor   = RfcEditorRepository.new(site: setting('SITE', 'https://www.rfc-editor.org'), user_agent: USER_AGENT)
    reads    = read_repository
    @library = library_service(editor, reads)
    @reading = ReadingService.new(texts: TextRepository.new(setting('TEXTS', data('rfc'))), editor: editor,
                                  reads: reads, reflow: ReflowService.new)
  end

  # The services by name.
  def services = { library: @library, reading: @reading }

  # Starts the thread that imports the index now when there is none (or it
  # is stale) and looks again every CHECK_EVERY seconds; a failure is
  # logged and tried again after RETRY_AFTER seconds.
  def start
    BBS.background('index refresh', every: CHECK_EVERY, retry_after: RETRY_AFTER, max_retry: CHECK_EVERY) do
      @library.refresh
    end
    self
  end

  private

  def setting(name, default) = @env.fetch("HACKERCAVE_BBS_#{name}", default)

  def data(name) = File.join(ROOT, 'data', name)

  def read_repository
    db = BBS::SQLite.new(setting('DB', data('hackercave.sqlite3')))
    db.migrate(*ReadRepository::MIGRATIONS)
    ReadRepository.new(db)
  end

  def library_service(editor, reads)
    LibraryService.new(index: IndexRepository.new(setting('INDEX_DB', data('index.sqlite3'))),
                       shelves: ShelvesRepository.new(setting('SHELVES', File.join(ROOT, 'config/shelves.yml'))),
                       reads: reads, editor: editor, index_file: setting('INDEX_FILE', data('rfc-index.xml')),
                       ttl: Float(setting('INDEX_TTL', '1')) * 86_400)
  end
end
