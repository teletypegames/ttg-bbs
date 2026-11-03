# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the modern face (the methods of its Application): the
    # library's lists opened in windows, the search, opening a book and
    # the desktop around them.
    module Library
      QR_PADDING = { sides: 2, top: 1, bottom: 0 }.freeze
      QR_SIDES   = 4
      QR_ROWS    = 7

      def library = services[:library]
      def reading = services[:reading]

      def classics = open_books(library.classics_shelf)

      def shelf_list
        return preparing unless library.ready?

        open_window(:shelves, shelves: library.shelves)
      end

      def open_books(shelf)
        books = library.books_on(shelf)
        title = shelf.classics? ? ' Classics ' : " #{shelf.label} (#{books.size} of #{shelf.count}) "
        open_window(:books, books: books, title: title)
      end

      def most_read
        list = library.most_read
        return BBS::Dialogs.message(self, 'Nothing has been read here yet.', title: ' Most read ') if list.empty?

        open_window(:books, books: list.map(&:first), title: ' Most read on this board ',
                            counts: list.to_h { |b, n| [b.id, n] })
      end

      def search
        BBS::Dialogs.input(self, prompt: 'Title or author words (lang:fr for one language):', title: ' Search ',
                                 value: context[:query].to_s, width: 64,
                                 on_submit: ->(query) { find(query) })
      end

      def find(query)
        context[:query] = query
        case (books = library.search(query))
        when :preparing then preparing
        when :too_short then BBS::Dialogs.message(self, 'A word of two letters or more, please.', title: ' Search ')
        when [] then BBS::Dialogs.message(self, 'Nothing found. Fewer or other words?', title: ' Search ')
        else open_window(:books, books: books, title: " Search: #{query.strip[0, 40]} (#{books.size}) ")
        end
      end

      def preparing
        BBS::Dialogs.message(self, 'The catalog is being prepared: it is downloaded from Project Gutenberg ' \
                                   'and indexed. Try again in a minute. The Classics shelf is open meanwhile.',
                             title: ' Catalog ', width: 60)
      end

      def open_book(book)
        title = book.short_title[0, 36]
        text = with_loading("Opening #{title}…") { reading.open(book, seen: context[:seen] ||= Set.new) }
        return open_window(:chapters, book: book, text: text) unless text.is_a?(Symbol)

        BBS::Dialogs.message(self, refusal(text), title: ' Open book ', width: 60)
      end

      def refusal(why)
        case why
        when :too_big then "This book is longer than the #{reading.max_bytes / (1024 * 1024)} MB the board takes."
        when :empty then 'There is no text in this ebook, only the licence. It may be a picture or a recording.'
        else 'Project Gutenberg did not give a plain text of this book. It may only have another format, ' \
             'or the site may be busy: try again later.'
        end
      end

      def read(book, text, number) = ReaderWindow.open(self, reading: reading, book: book, text: text, number: number)

      # The book's Project Gutenberg page as a QR code, for a phone or an
      # e-reader to take the whole book.
      def show_qr(book)
        code = qr_code(book.link, width: cols - QR_SIDES, height: rows - QR_ROWS)
        BBS::Windows::Info.open(self, title: " eBook ##{book.id} on your phone ",
                                      width: BBS::FrameBuffer.plain(code.first).size + QR_SIDES,
                                      body: code, padding: QR_PADDING)
        :keep
      rescue BBS::QR::TooLong
        BBS::Dialogs.message(self, "The screen is too small for a QR code. The book is at #{book.url}.", title: ' QR code ')
        :keep
      end

      def qr_code(link, **room)
        BBS::QR.ansi(link, **room)
      rescue BBS::QR::TooLong
        BBS::QR.ansi(link, **room, quiet: 1)
      end

      def selected(window) = window.list_widget.selected_item

      def help(text, title) = BBS::Dialogs.message(self, text, title: title, width: 64)
    end
  end
end
