# frozen_string_literal: true

require 'open3'

# The full text of every RFC: #refresh mirrors the RFC Editor's
# rfcs-text-only rsync module into the text folder (TextRepository, so the
# reader finds the texts there too), fetches the IENs that are plain text,
# and indexes whatever is new or changed (FulltextRepository), one text at a
# time so memory stays flat. #search finds the RFCs that have the words, and
# the first line of each that has the first word. Runs in a BBS.background
# thread once a day; the first run takes a while (about 540 MB).
class MirrorService
  SOURCE  = 'rsync://rsync.rfc-editor.org/rfcs-text-only/'
  # Seconds the rsync may take; it goes on where it stopped the next time.
  TIMEOUT = 3 * 3600
  # The longest line a search shows of a hit.
  LINE = 72
  # Texts indexed between two garbage collections: the heap stays small.
  GC_EVERY = 200

  # [texts]    the TextRepository the mirror fills
  # [fulltext] the FulltextRepository
  # [index]    the IndexRepository (which IENs are text)
  # [editor]   the RfcEditorRepository (the IEN texts)
  # [ttl]      seconds between two syncs
  # [rsync]    a callable that runs rsync with its arguments; true when it succeeded
  def initialize(texts:, fulltext:, index:, editor:, ttl:, source: SOURCE, rsync: nil)
    @texts    = texts
    @fulltext = fulltext
    @index    = index
    @editor   = editor
    @ttl      = ttl
    @source   = source
    @rsync    = rsync || method(:run_rsync)
    @synced   = nil
  end

  def ready? = @fulltext.ready?

  # How many texts are indexed.
  def count = @fulltext.count

  # Syncs and indexes when the last sync is older than the TTL (or with
  # +force+). Returns the number of texts indexed now, or :fresh.
  def refresh(force: false)
    return :fresh unless force || @synced.nil? || Time.now - @synced > @ttl

    started = Time.now
    BBS.log('mirror', 'rsync failed; indexing what is there') unless @rsync.call(rsync_args)
    fetch_iens
    n = index_changed
    @synced = Time.now
    BBS.log('mirror', format('%<n>d texts indexed in %<s>.0f s, %<all>d in all', n: n, s: Time.now - started, all: count))
    n
  end

  # The RFCs whose text has every word of +words+ as [number, line]: the
  # first line that has the first word, trimmed.
  def search(words, limit:)
    @fulltext.search(words, limit: limit).map { |number| [number, line_with(number, words.first)] }
  end

  private

  def rsync_args = ['-rt', '--timeout=300', '--include=rfc*.txt', '--exclude=*', @source, "#{@texts.dir}/"]

  def run_rsync(args)
    FileUtils.mkdir_p(@texts.dir)
    out, status = Open3.capture2e('timeout', TIMEOUT.to_s, 'rsync', *args)
    BBS.log('mirror', "rsync: #{out.lines.last(2).join.strip}") unless status.success?
    status.success?
  rescue SystemCallError => e
    BBS.log('mirror', "rsync: #{e.message}")
    false
  end

  # The IENs the RFC Editor has as text and the folder has not.
  def fetch_iens
    @index.iens.select(&:text?).reject { |ien| @texts.exist?(ien.number) }.each do |ien|
      @texts.store(ien.number, @editor.text(ien.number))
    rescue BBS::HTTP::Error => e
      BBS.log('mirror', "#{ien.name}: #{e.message}")
    end
  end

  # Indexes the texts whose size or mtime changed since they were indexed;
  # their number.
  def index_changed
    known = @fulltext.stats
    changed = @texts.stats.reject { |number, stat| known[number] == stat }
    changed.each_with_index do |(number, (size, mtime)), i|
      body = @texts.read(number) or next
      @fulltext.put(number, body, size: size, mtime: mtime)
      GC.start if (i % GC_EVERY).zero?
    end
    changed.size
  end

  def line_with(number, word)
    text = @texts.read(number).to_s
    hit = text.each_line.find { |l| l.match?(/\b#{Regexp.escape(word)}/i) }
    hit.to_s.strip.squeeze(' ')[0, LINE]
  end
end
