# frozen_string_literal: true

# Reading a book: its text fetched from Project Gutenberg once, cleaned and
# cut into chapters (ChapterService), then kept in the text cache; a
# chapter is read from there when it is shown. One book is fetched and cut
# at a time, so a few callers opening big books at once do not run the
# board out of memory.
class ReadingService
  def initialize(gutenberg:, cache:, reads:, chapters:, max_bytes:)
    @gutenberg = gutenberg
    @cache     = cache
    @reads     = reads
    @chapters  = chapters
    @max_bytes = max_bytes
    @fetching  = Mutex.new
  end

  attr_reader :max_bytes

  def cached?(book) = !@cache.index(book.id).nil?

  # The TextModel of +book+, or why not: :too_big (longer than the board
  # takes), :unavailable (no plain text from the mirror), :empty (nothing
  # left after the licence is taken off). +seen+, a Set the caller keeps for
  # the call, makes a book count as read once a call.
  def open(book, seen: nil)
    text = @cache.index(book.id) || @fetching.synchronize { @cache.index(book.id) || fetch(book.id) }
    return text if text.is_a?(Symbol)

    if seen && !seen.include?(book.id)
      seen << book.id
      @reads.add(book.id)
    end
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

  def fetch(id)
    raw = @gutenberg.text(id, max_bytes: @max_bytes)
    return :too_big if raw == :too_big
    return :unavailable if raw.nil?

    clean = @chapters.clean(raw)
    cuts = @chapters.cut(clean)
    return :empty if cuts.empty?

    @cache.store(id, clean, cuts) || :unavailable
  end
end
