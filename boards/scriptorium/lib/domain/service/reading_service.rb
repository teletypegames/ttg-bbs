# frozen_string_literal: true

# Reading a book: its text fetched from Project Gutenberg once, cleaned and
# cut into chapters (ChapterService), then kept in the text cache; a
# chapter is read from there when it is shown. Callers opening the same
# book wait for one fetch (a BBS::Cache single flight), and at most
# FETCHES books are fetched and cut at once, so a few callers opening big
# books together do not run the board out of memory; a caller waits for
# a turn no longer than WAIT seconds.
class ReadingService
  FETCHES = 2
  WAIT    = 60
  # Seconds an answer of the mirror is kept: a refusal is not asked again
  # by every caller.
  REMEMBER = 30

  def initialize(gutenberg:, cache:, reads:, chapters:, max_bytes:)
    @gutenberg = gutenberg
    @cache     = cache
    @reads     = reads
    @chapters  = chapters
    @max_bytes = max_bytes
    @opening   = BBS::Cache.new(ttl: REMEMBER, max_entries: 64)
    @turns     = SizedQueue.new(FETCHES)
    FETCHES.times { @turns << :turn }
  end

  attr_reader :max_bytes

  def cached?(book) = !@cache.index(book.id).nil?

  # The TextModel of +book+, or why not: :too_big (longer than the board
  # takes), :unavailable (no plain text from the mirror, or the board is
  # busy), :empty (nothing left after the licence is taken off). +seen+, a
  # Set the caller keeps for the call, makes a book count as read once a
  # call.
  def open(book, seen: nil)
    text = @cache.index(book.id) || @opening.fetch(book.id) { @cache.index(book.id) || in_turn { fetch(book.id) } }
    return text if text.is_a?(Symbol)

    count_read(book.id, seen)
    text
  end

  # The text of chapter +number+ of +text+: paragraphs separated by an
  # empty line; nil when there is no such chapter or the cache lost it.
  def chapter(text, number)
    ch = text.chapter(number)
    ch && @cache.read(text.book_id, ch)&.strip
  end

  # The first +chars+ characters of chapter +number+, on one line.
  def preview(text, number, chars = 400)
    body = chapter(text, number)
    body && body.split("\n\n").drop(1).join(' ').tr("\n", ' ')[0, chars]
  end

  private

  def count_read(id, seen)
    return unless seen && !seen.include?(id)

    seen << id
    @reads.add(id)
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

  def fetch(id)
    clean = @chapters.clean(@gutenberg.text(id, max_bytes: @max_bytes))
    cuts = @chapters.cut(clean)
    return :empty if cuts.empty?

    @cache.store(id, clean, cuts) || :unavailable
  rescue BBS::HTTP::TooLarge
    :too_big
  rescue BBS::HTTP::Error => e
    BBS.log('gutenberg', "book #{id}: #{e.message}")
    :unavailable
  end
end
