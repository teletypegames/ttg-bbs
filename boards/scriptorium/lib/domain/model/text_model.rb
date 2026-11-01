# frozen_string_literal: true

# A book ready to read: its number, the size of the cleaned text and its
# chapters. The text itself stays on disk; a chapter is read when shown.
TextModel = Data.define(:book_id, :bytes, :chapters) do
  # The index as JSON-ready data.
  def to_h = { 'book_id' => book_id, 'bytes' => bytes, 'chapters' => chapters.map { |c| [c.title, c.offset, c.length] } }

  # The text of an index written by #to_h; nil when it is not one.
  def self.from_h(data)
    chapters = data.fetch('chapters').each_with_index.map do |(title, offset, length), i|
      ChapterModel.new(number: i + 1, title: title.to_s, offset: Integer(offset), length: Integer(length))
    end
    new(book_id: Integer(data.fetch('book_id')), bytes: Integer(data.fetch('bytes')), chapters: chapters.freeze)
  rescue KeyError, TypeError, ArgumentError, NoMethodError
    nil
  end

  def chapter(number) = number.between?(1, chapters.size) ? chapters[number - 1] : nil

  def size = chapters.size
end
