# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the library's lists opened
    # in windows, the search, opening a book, its QR code.
    module Library
      PREPARING = 'The catalog is being prepared: it is downloaded from Project Gutenberg ' \
                  'and indexed. Try again in a minute. The Classics shelf is open meanwhile.'

      def thousands(number) = number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse

      def classics = open_books(library.classics_shelf)

      def shelf_list
        return preparing unless library.ready?

        show(:shelves, shelves: library.shelves)
      end

      def open_books(shelf)
        books = library.books_on(shelf)
        show(:books, books: books, heading: shelf.classics? ? 'Classics' : "#{shelf.label} (#{books.size} of #{shelf.count})")
      end

      def most_read
        list = library.most_read
        return message('Nothing has been read here yet.', title: 'Most read') if list.empty?

        show(:books, books: list.map(&:first), heading: 'Most read on this board', counts: list.to_h { |b, n| [b.id, n] })
      end

      def search
        ask(
          'Title or author words (lang:fr for one language):',
          title: 'Search',
          value: context[:query].to_s,
          width: 64
        ) { |query| find(query) }
      end

      def find(query)
        context[:query] = query
        case (books = library.search(query))
        when :preparing then preparing
        when :too_short then message('A word of two letters or more, please.', title: 'Search')
        when [] then message('Nothing found. Fewer or other words?', title: 'Search')
        else show(:books, books: books, heading: "Search: #{query.strip[0, 40]} (#{books.size})")
        end
      end

      def preparing = message(PREPARING, title: 'Catalog', width: 60)

      def open_book(book)
        text = loading("Opening #{book.short_title[0, 36]}…") { reading.open(book, seen: context[:seen] ||= Set.new) }
        return show(:chapters, book: book, text: text) unless text.is_a?(Symbol)

        message(refusal(text), title: 'Open book', width: 60)
      end

      def refusal(why)
        case why
        when :too_big then "This book is longer than the #{reading.max_bytes / (1024 * 1024)} MB the board takes."
        when :empty then 'There is no text in this ebook, only the licence. It may be a picture or a recording.'
        else 'Project Gutenberg did not give a plain text of this book. It may only have another format, ' \
             'or the site may be busy: try again later.'
        end
      end

      # The book's Project Gutenberg page as a QR code, for a phone or an
      # e-reader to take the whole book.
      def show_qr(book) = qr(book.link, title: "eBook ##{book.id} on your phone")
    end
  end
end
