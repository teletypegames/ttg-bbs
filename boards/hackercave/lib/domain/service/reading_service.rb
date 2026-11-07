# frozen_string_literal: true

# Reading an RFC: its text from the disk (TextRepository), or fetched from
# the RFC Editor the first time and kept there; then parsed into a
# DocumentModel, which stays in memory for a while. Callers opening the same
# RFC wait for one fetch (a Rubbs::Common::Storage::Cache single flight), and at most FETCHES
# RFCs are fetched at once; a caller waits for a turn no longer than WAIT
# seconds. The C64 face reads the RFC reflowed (ReflowService), kept the
# same way.
class ReadingService
  FETCHES = 2
  # An RFC or IEN named in a text.
  MENTION = /\b(RFC|IEN)[ -]?(\d{1,5})\b/i
  WAIT    = 60
  # Seconds a parsed RFC is kept in memory.
  KEEP = 900

  def initialize(texts:, editor:, reflow:)
    @texts     = texts
    @editor    = editor
    @reflow    = reflow
    @documents = Rubbs::Common::Storage::Cache.new(ttl: KEEP, max_entries: 24)
    @flowed    = Rubbs::Common::Storage::Cache.new(ttl: KEEP, max_entries: 24)
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
  def kinds(doc) = @flowed.fetch([doc.number, :kinds]) { @reflow.kinds(doc) }

  # The headings of +doc+ as [line index, text]: its table of contents.
  def contents(doc) = kinds(doc).each_with_index.filter_map { |kind, i| [i, doc.lines[i].strip] if kind == :heading }

  # The RFCs and IENs +doc+ mentions ("RFC 793", "[RFC2119]", "IEN 116"),
  # each once, in the order they first come, as [number, line index]; an
  # IEN's number negative. +doc+ itself is left out.
  def mentions(doc)
    seen = {}
    doc.lines.each_with_index do |line, i|
      line.scan(MENTION) { |kind, n| seen[kind.upcase == 'IEN' ? -n.to_i : n.to_i] ||= i }
    end
    seen.delete(doc.number)
    seen.to_a
  end

  private

  def count_read(number, seen)
    return unless seen && !seen.include?(number)

    seen << number
    Rubbs.achieve(:read, kind: number.negative? ? 'ien' : 'rfc', ref: number.abs.to_s)
    ReadModel.add(number)
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
  rescue Rubbs::Common::Web::HTTP::Error => e
    Rubbs.log('rfc-editor', "RFC #{number}: #{e.message}")
    e.message.include?('answered 404') ? :no_text : :unavailable
  end
end
