# frozen_string_literal: true

module UI
  class Petscii < Rubbs::Petscii::Face
    # The reader of the C64 face: a book's chapter in pages of ROWS lines.
    # RETURN turns the page (and at the end of a chapter goes on to the
    # next one), B goes back a page, N and P change the chapter, Q goes back
    # to the list.
    class Reader
      # Rows of text on a page: the title bar above, the key line below.
      ROWS = 21
      UNREADABLE = '(This chapter could not be read. Try again later.)'

      def initialize(face, book, text)
        @face = face
        @book = book
        @text = text
      end

      # Reads from chapter +number+ until the caller goes back.
      def read(number)
        open_chapter(number)
        loop do
          show_page
          step = reader_key
          break if step == :quit

          turn(step)
        end
      end

      private

      def open_chapter(number)
        @number = number
        @page   = 0
        @lines  = chapter_lines
      end

      def pages = [(@lines.size + ROWS - 1) / ROWS, 1].max

      def last_page? = @page == pages - 1

      def show_page
        @page = @page.clamp(0, pages - 1)
        @face.title(@text.chapter(@number).title[0, 24], "#{@number}/#{@text.size} p#{@page + 1}/#{pages}")
        rows = @lines[@page * ROWS, ROWS]
        rows.each { |l| @face.puts l }
        (ROWS - rows.size).times { @face.puts }
        @face.write " #{DG}ret:#{last_page? ? 'next ch' : 'more'} b:back n/p:chapter q:list#{LG}"
      end

      def turn(step)
        case step
        when :back then @page -= 1
        when :more then @page += 1
        when Integer then open_chapter(@number + step)
        end
      end

      def reader_key
        loop do
          key  = @face.key
          step = step_of(key.is_a?(String) ? key.downcase : key)
          return step if step
        end
      end

      # What a key does: :more, :back, :quit, or a chapter step (1 or -1);
      # nil for a key that does nothing.
      def step_of(key)
        case key
        when :enter, ' ' then last_page? ? next_chapter : :more
        when 'b', :up then :back
        when 'n' then next_chapter
        when 'p' then @number > 1 ? -1 : :back
        when 'q', :escape then :quit
        end
      end

      def next_chapter = @number < @text.size ? 1 : :quit

      # The chapter wrapped to 38 columns in characters the C64 has, the
      # heading in white, a blank line between paragraphs.
      def chapter_lines
        body = @face.reading.chapter(@text, @number) || UNREADABLE
        body.split("\n\n").each_with_index.flat_map do |para, i|
          lines = para.split("\n").flat_map { |line| @face.wrap(@face.plain(line), WIDTH) }
          lines = lines.map { |l| i.zero? ? " #{WH}#{l}#{LG}" : " #{l}" }
          i.zero? ? lines : ['', *lines]
        end
      end
    end
  end
end
