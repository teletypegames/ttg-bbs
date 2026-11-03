# frozen_string_literal: true

# Reading an RFC: its text from the disk (TextRepository), or fetched from
# the RFC Editor the first time and kept there; then parsed into a
# DocumentModel, which stays in memory for a while. Callers opening the same
# RFC wait for one fetch (a BBS::Cache single flight), and at most FETCHES
# RFCs are fetched at once; a caller waits for a turn no longer than WAIT
# seconds. The C64 face reads the RFC reflowed (ReflowService), kept the
# same way.
class ReadingService
  FETCHES = 2
  WAIT    = 60
  # Seconds a parsed RFC is kept in memory.
  KEEP = 900

  def initialize(texts:, editor:, reads:, reflow:)
    @texts     = texts
    @editor    = editor
    @reads     = reads
    @reflow    = reflow
    @documents = BBS::Cache.new(ttl: KEEP, max_entries: 24)
    @flowed    = BBS::Cache.new(ttl: KEEP, max_entries: 24)
    @turns     = SizedQueue.new(FETCHES)
    FETCHES.times { @turns << :turn }
  end

  def here?(rfc) = @texts.exist?(rfc.number)

  # The DocumentModel of +rfc+, or why not: :no_text (the RFC Editor has no
  # plain text of it) or :unavailable (the site did not answer, or the board
  # is busy). +seen+, a Set the caller keeps for the call, makes an RFC count
  # as read once a call.
  def open(rfc, seen: nil)
    doc = @documents.fetch(rfc.number) { load(rfc.number) }
    if doc.is_a?(Symbol)
      @documents.delete(rfc.number)
      return doc
    end
    count_read(rfc.number, seen)
    doc
  end

  # The lines of +doc+ reflowed to +width+ (ReflowService::Line).
  def reflowed(doc, width) = @flowed.fetch([doc.number, width]) { @reflow.reflow(doc, width) }

  # The kind of each line of +doc+ (ReflowService#kinds).
  def kinds(doc) = @reflow.kinds(doc)

  private

  def count_read(number, seen)
    return unless seen && !seen.include?(number)

    seen << number
    @reads.add(number)
  end

  def load(number)
    text = @texts.read(number) || in_turn { fetch(number) }
    text.is_a?(Symbol) ? text : DocumentModel.parse(number, text)
  end

  # Runs the block in one of the FETCHES turns; :unavailable when none
  # comes within WAIT seconds.
  def in_turn
    turn = @turns.pop(timeout: WAIT) or return :unavailable
    begin
      yield
    ensure
      @turns << turn
    end
  end

  # The text of RFC +number+ from the RFC Editor, kept on the disk.
  def fetch(number)
    @texts.read(number) || begin
      bytes = @editor.text(number)
      @texts.store(number, bytes)
      bytes.dup.force_encoding(Encoding::UTF_8).scrub('?')
    end
  rescue BBS::HTTP::Error => e
    BBS.log('rfc-editor', "RFC #{number}: #{e.message}")
    e.message.include?('answered 404') ? :no_text : :unavailable
  end
end
