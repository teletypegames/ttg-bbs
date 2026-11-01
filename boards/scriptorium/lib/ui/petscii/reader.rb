# frozen_string_literal: true

module UI
  module Petscii
    # The reader of the C64 face: a book's chapter in pages of ROWS lines.
    # RETURN turns the page (and at the end of a chapter goes on to the
    # next one), B goes back a page, N and P change the chapter, Q goes back
    # to the list.
    class Reader
      # Rows of text on a page: the title bar above, the key line below.
      ROWS = 21

      def initialize(screen, reading, book, text)
        @screen  = screen
        @reading = reading
        @book    = book
        @text    = text
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
      ensure
        @screen.puts
        @screen.title(@book.short_title.upcase[0, 26], "#{@text.size} ch")
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
        @screen.title(@text.chapter(@number).title[0, 24], "#{@number}/#{@text.size} p#{@page + 1}/#{pages}")
        rows = @lines[@page * ROWS, ROWS]
        rows.each { |l| @screen.puts l }
        (ROWS - rows.size).times { @screen.puts }
        @screen.write " #{DG}ret:#{last_page? ? 'next ch' : 'more'} b:back n/p:chapter q:list#{LG}"
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
          step = step_of(key)
          return step if step
        end
      end

      def key
        k = @screen.key
        k.is_a?(String) ? k.downcase : k
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
        body = @reading.chapter(@text, @number) || '(This chapter could not be read. Try again later.)'
        body.split("\n\n").each_with_index.flat_map do |para, i|
          lines = para.split("\n").flat_map { |line| @screen.wrap(@screen.plain(line), WIDTH) }
          lines = lines.map { |l| i.zero? ? " #{WH}#{l}#{LG}" : " #{l}" }
          i.zero? ? lines : ['', *lines]
        end
      end
    end
  end
end
