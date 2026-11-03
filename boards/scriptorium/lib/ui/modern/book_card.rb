# frozen_string_literal: true

module UI
  module Modern
    # A book's record on the right of a list of books: the title, the
    # authors, the facts, the subjects and the shelves, and the credit.
    module BookCard
      def book_lines(book)
        [*book_heading(book), '', *book_topics(book), card_credit(book), '', dim('Enter opens the book.')]
      end

      private

      def book_heading(book)
        authors = book.author_names.empty? ? 'Anonymous' : book.author_names.join(', ')
        [bright(book.short_title), *(dim(book.subtitle) unless book.subtitle.empty?), accent("by #{authors}"),
         dim(book_facts(book).join(' · '))]
      end

      def book_facts(book)
        reads = library.reads(book)
        ["Language: #{book.language}", ("Issued: #{book.issued}" unless book.issued.empty?),
         "Read #{reads} time#{'s' unless reads == 1} here"].compact
      end

      # The subjects and the bookshelves, then an empty line; nothing when
      # the book has neither.
      def book_topics(book)
        lines = []
        lines << "#{paint(:label, 'Subjects:')} #{book.subject_list.first(6).join('; ')}" unless book.subjects.empty?
        lines << "#{paint(:label, 'Bookshelves:')} #{book.shelf_names.first(6).join('; ')}" unless book.bookshelves.empty?
        lines.empty? ? lines : [*lines, '']
      end

      def card_credit(book) = "eBook ##{book.id} from Project Gutenberg, #{book.url} — public domain in the USA."
    end
  end
end
