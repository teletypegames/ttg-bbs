# frozen_string_literal: true

module UI
  module Modern
    # A book read chapter by chapter: the chapter wrapped to the window, a
    # line under it that says where the reader is ("Chapter 3/42 · page
    # 2/9"), Prev and Next (and ← →) for the previous and the next chapter.
    module ReaderWindow
      extend Rubbs::Modern::Part

      window :reader, :reader do
        title     { bookmark.book.short_title }
        max_width 100
        lines     { |width| chapter_lines(bookmark, width) }
        where     { |view| chapter_where(bookmark, view) }
        action('Prev') { |reader| turn(reader, bookmark, -1) }
        action('Next') { |reader| turn(reader, bookmark, 1) }
        on_key(left: ->(reader, _key) { turn(reader, bookmark, -1) }, right: ->(reader, _key) { turn(reader, bookmark, 1) })
      end
    end
  end
end
