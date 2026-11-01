# frozen_string_literal: true

module UI
  module Modern
    # A book's record on the right of a list of books: the title, the
    # authors, the facts, the subjects and the shelves, and the credit.
    module BookCard
      def book_lines(book, width)
        wrap = ->(s) { BBS::FrameBuffer.wrap_ansi(s, width - 1) }
        [*book_heading(book), '', *book_topics(book), card_credit(book), '',
         "#{theme[:text_dim]}Enter opens the book.#{theme[:text]}"].flat_map { |line| line.empty? ? [line] : wrap.call(line) }
      end

      private

      def book_heading(book)
        t = theme
        authors = book.author_names.empty? ? 'Anonymous' : book.author_names.join(', ')
        ["#{t[:text_bright]}#{book.short_title}#{t[:text]}",
         *("#{t[:text_dim]}#{book.subtitle}#{t[:text]}" unless book.subtitle.empty?),
         "#{t[:accent]}by #{authors}#{t[:text]}",
         "#{t[:text_dim]}#{book_facts(book).join(' · ')}#{t[:text]}"]
      end

      def book_facts(book)
        reads = library.reads(book)
        ["Language: #{book.language}", ("Issued: #{book.issued}" unless book.issued.empty?),
         "Read #{reads} time#{'s' unless reads == 1} here"].compact
      end

      # The subjects and the bookshelves, then an empty line; nothing when
      # the book has neither.
      def book_topics(book)
        t = theme
        lines = []
        lines << "#{t[:label]}Subjects:#{t[:text]} #{book.subject_list.first(6).join('; ')}" unless book.subjects.empty?
        lines << "#{t[:label]}Bookshelves:#{t[:text]} #{book.shelf_names.first(6).join('; ')}" unless book.bookshelves.empty?
        lines.empty? ? lines : [*lines, '']
      end

      def card_credit(book) = "eBook ##{book.id} from Project Gutenberg, #{book.url} — public domain in the USA."
    end
  end
end
