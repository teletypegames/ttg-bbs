# frozen_string_literal: true

module UI
  module Modern
    # Reading a book in the reader window: where the caller is in it, the
    # chapter as lines, the turn to another. Only the chapter shown is in
    # memory; the next one is read from the cache when the reader turns to
    # it.
    module Chapters
      UNREADABLE = '(This chapter could not be read. Try again later.)'

      # The book, its text and the chapter open in a reader.
      Bookmark = Struct.new(:book, :text, :number, :paragraphs)

      # ← and → in the text of a reader turn the chapter.
      module TurnKeys
        attr_accessor :on_turn

        def handle_event(event)
          return super unless on_turn && event.key? && %i[left right].include?(event.key)

          on_turn.call(event.key == :left ? -1 : 1)
          :handled
        end
      end

      def read(book, text, number)
        bookmark = Bookmark.new(book, text, number)
        reader   = show(:reader, bookmark: bookmark)
        reader.view.extend(TurnKeys).on_turn = ->(step) { turn(reader, bookmark, step) }
        reader
      end

      def turn(reader, bookmark, step)
        number = bookmark.number + step
        return unless number.between?(1, bookmark.text.size)

        bookmark.number     = number
        bookmark.paragraphs = nil
        reader.lines = ->(width) { chapter_lines(bookmark, width) }
      end

      # The chapter wrapped to +width+, the heading bright, an empty line
      # between the paragraphs.
      def chapter_lines(bookmark, width)
        bookmark.paragraphs ||= (reading.chapter(bookmark.text, bookmark.number) || UNREADABLE).split("\n\n")
        bookmark.paragraphs.each_with_index.flat_map do |para, i|
          lines = para.split("\n").flat_map { |line| BBS::FrameBuffer.wrap_ansi(line, width) }
          i.zero? ? lines.map { |l| bright(l) } : ['', *lines]
        end
      end

      def chapter_where(bookmark, view)
        height = [view.bounds.height, 1].max
        pages  = [(view.lines.size + height - 1) / height, 1].max
        page   = [((view.scroll + height - 1) / height) + 1, pages].min
        title  = bookmark.text.chapter(bookmark.number)&.title
        "Chapter #{bookmark.number}/#{bookmark.text.size} · page #{page}/#{pages} · #{title}"
      end
    end
  end
end
