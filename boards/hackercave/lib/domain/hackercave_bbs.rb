# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the library (the index
# of the RFC Editor with the IENs and the errata, the board's own shelves,
# the reads), the reading room (the texts, fetched once and kept on the
# disk), the mirror of every RFC's text with its full-text index, and the
# Jargon File. The index and the mirror are kept fresh in the background.
class HackerCaveBBS
  include BBS::Domain

  # How often the refreshers look at the age of what they keep, in seconds.
  CHECK_EVERY = 3600
  # Seconds before a failed refresh is tried again (doubled up to
  # CHECK_EVERY).
  RETRY_AFTER = 300
  DAY = 86_400
  JARGON_SOURCE = 'config/jargon/jarg447.txt'

  setting :site, 'https://www.rfc-editor.org'
  setting :index_ttl, 1.0
  setting :mirror, true
  setting :mirror_source, MirrorService::SOURCE
  setting :mirror_ttl, 1.0
  path    :db, 'data/hackercave.sqlite3'
  path    :shelves, 'config/shelves.yml'
  path    :texts, 'data/rfc'
  path    :index_db, 'data/index.sqlite3'
  path    :index_file, 'data/rfc-index.xml'
  path    :errata_file, 'data/errata.json'
  path    :fulltext_db, 'data/fulltext.sqlite3'
  path    :jargon_db, 'data/jargon.sqlite3'

  database :db, MIGRATIONS
  database :index_db, INDEX_MIGRATIONS, name: :index
  database :fulltext_db, FULLTEXT_MIGRATIONS, name: :fulltext
  database :jargon_db, JARGON_MIGRATIONS, name: :jargon

  service(:library) { LibraryService.new(mirror: mirror_service, shelves: ShelvesRepository.new(shelves)) }
  service(:reading) { ReadingService.new(texts: text_repository, editor: editor, reflow: ReflowService.new) }
  service(:jargon) { JargonService.new(file: JargonFileRepository.new(File.expand_path(JARGON_SOURCE, self.class.root))) }

  background('jargon') { jargon.prepare }
  background('index refresh', every: CHECK_EVERY, retry_after: RETRY_AFTER, max_retry: CHECK_EVERY) do
    import.refresh
    mirror_service&.refresh
  end

  private

  def editor = @editor ||= RfcEditorRepository.new(site: site)

  def text_repository = @text_repository ||= TextRepository.new(texts)

  def import
    @import ||= ImportService.new(editor: editor, index_file: index_file, errata_file: errata_file, ttl: index_ttl * DAY)
  end

  # The mirror, or nil when HACKERCAVE_BBS_MIRROR is off.
  def mirror_service
    return nil unless mirror

    @mirror_service ||= MirrorService.new(texts: text_repository, editor: editor, source: mirror_source, ttl: mirror_ttl * DAY)
  end
end
