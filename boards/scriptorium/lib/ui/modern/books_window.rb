# frozen_string_literal: true

module UI
  module Modern
    # A list of books (a shelf, a search, the most read) on the left, the
    # record of the one picked on the right; Enter opens it.
    module BooksWindow
      extend BBS::Part

      window :books, :master_detail do
        title      { heading }
        height     { rows - 8 }
        list_width { [36, (cols / 2) - 4].min }
        items      { books }
        label do |book|
          count = extras[:counts]&.fetch(book.id, nil)
          count ? "#{count.to_s.rjust(3)}  #{book.short_title}" : book.short_title
        end
        empty      'No books here.'
        detail     { |book| book_lines(book) }
        meta       { |book| "eBook ##{book.id} · #{book.language}" }
        on_pick    { |book| open_book(book) }
        action('Read') { |book| open_book(book) }
        action('QR code') { |book| show_qr(book) }
      end
    end
  end
end
