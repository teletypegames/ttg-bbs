# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the index
# of the RFC Editor with the IENs and the errata, the board's own shelves,
# the reads), the reading room (the texts, fetched once and kept on the
# disk), the mirror of every RFC's text with its full-text index, and the
# Jargon File. Both faces (lib/ui/modern, lib/ui/petscii) work on one
# instance of it. The only place that reads the environment. #start keeps
# the index and the mirror fresh in BBS.background threads.
class HackerCaveBBS
  ROOT = File.expand_path('../..', __dir__)
  USER_AGENT = 'HackerCaveBBS/1.0 (telnet board of Teletype Games; +https://teletypegames.org)'
  # How often the refreshers look at the age of what they keep, in seconds.
  CHECK_EVERY = 3600
  # Seconds before a failed refresh is tried again (doubled up to
  # CHECK_EVERY).
  RETRY_AFTER = 300

  attr_reader :library, :reading, :jargon, :mirror

  def initialize(env = ENV)
    @env    = env
    editor  = RfcEditorRepository.new(site: setting('SITE', 'https://www.rfc-editor.org'), user_agent: USER_AGENT)
    reads   = read_repository
    texts   = TextRepository.new(setting('TEXTS', data('rfc')))
    index   = IndexRepository.new(setting('INDEX_DB', data('index.sqlite3')))
    @import = import_service(index, editor)
    @mirror = mirror_service(texts, index, editor)
    @library = LibraryService.new(index: index, reads: reads, mirror: @mirror,
                                  shelves: ShelvesRepository.new(setting('SHELVES', File.join(ROOT, 'config/shelves.yml'))))
    @reading = ReadingService.new(texts: texts, editor: editor, reads: reads, reflow: ReflowService.new)
    @jargon  = JargonService.new(repository: JargonRepository.new(setting('JARGON_DB', data('jargon.sqlite3')),
                                                                   source: File.join(ROOT, 'config/jargon/jarg447.txt')))
  end

  # The services by name.
  def services = { library: @library, reading: @reading, jargon: @jargon }

  # Starts the threads: the Jargon File's database once, the index now when
  # there is none (or it is stale) and the mirror after it, both looked at
  # again every CHECK_EVERY seconds; a failure is logged and tried again
  # after RETRY_AFTER seconds.
  def start
    BBS.background('jargon') { @jargon.prepare }
    BBS.background('index refresh', every: CHECK_EVERY, retry_after: RETRY_AFTER, max_retry: CHECK_EVERY) do
      @import.refresh
      @mirror&.refresh
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

  def import_service(index, editor)
    ImportService.new(index: index, editor: editor, index_file: setting('INDEX_FILE', data('rfc-index.xml')),
                      errata_file: setting('ERRATA_FILE', data('errata.json')),
                      ttl: Float(setting('INDEX_TTL', '1')) * 86_400)
  end

  # The mirror, or nil when HACKERCAVE_BBS_MIRROR is "off".
  def mirror_service(texts, index, editor)
    return nil if setting('MIRROR', 'on') == 'off'

    MirrorService.new(texts: texts, index: index, editor: editor,
                      fulltext: FulltextRepository.new(setting('FULLTEXT_DB', data('fulltext.sqlite3'))),
                      source: setting('MIRROR_SOURCE', MirrorService::SOURCE),
                      ttl: Float(setting('MIRROR_TTL', '1')) * 86_400)
  end
end
