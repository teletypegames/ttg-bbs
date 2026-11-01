# frozen_string_literal: true

module UI
  module Modern
    # A list of books (a shelf, a search, the most read) on the left, the
    # record of the one picked on the right; Enter opens it.
    module BooksWindow
      def self.define(app)
        app.window(:books, type: :master_detail) do |w|
          frame(w)
          list(w)
          w.action(label: '&Read') { |win, ctx| read(win, ctx[:app]) }
        end
      end

      def self.frame(w)
        w.maximizable true
        w.title         { |ctx| ctx[:title] }
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [36, (ctx[:app].cols / 2) - 4].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:books] }
        w.item_label    { |b, ctx| label(b, ctx[:counts]) }
        w.empty_message 'No books here.'
        w.render_detail { |b, width, ctx| ctx[:app].book_lines(b, width) }
        w.bottom_meta { |b, _ctx| "eBook ##{b.id} · #{b.language}" }
        w.on_activate { |b, _window, ctx| ctx[:app].open_book(b) }
      end

      # The title, after the number of reads in the Most read list.
      def self.label(book, counts)
        count = counts&.fetch(book.id, nil)
        count ? "#{count.to_s.rjust(3)}  #{book.short_title}" : book.short_title
      end

      def self.read(window, app)
        book = app.selected(window)
        app.open_book(book) if book
        :keep
      end
    end
  end
end
