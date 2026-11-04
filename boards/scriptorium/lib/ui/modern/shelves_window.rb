# frozen_string_literal: true

module UI
  module Modern
    # The bookshelves of Project Gutenberg (and the Classics) on the left,
    # what a shelf is on the right; Enter opens its books.
    module ShelvesWindow
      extend BBS::Part

      KINDS = {
        classics:  "The board's own shelf of well-known books.",
        category:  'A category of Project Gutenberg.',
        bookshelf: 'A bookshelf of Project Gutenberg, gathered by its volunteers.'
      }.freeze
      LISTED = "The first #{LibraryService::SHELF_LIMIT} by ebook number are listed: " \
               'the oldest ebooks are the best known ones.'.freeze

      window :shelves, :master_detail do
        title 'Bookshelves'
        height     { rows - 8 }
        list_width { [34, (cols / 2) - 4].min }
        items      { shelves }
        label      :label
        empty 'No bookshelves yet.'
        detail do |shelf|
          kind = if shelf.classics? then :classics
                 elsif shelf.category? then :category
                 else :bookshelf
                 end
          [bright(shelf.label), accent("#{shelf.count} books"), '', KINDS[kind], '', dim(LISTED)]
        end
        meta       { 'Enter opens the shelf' }
        on_pick    { |shelf| open_books(shelf) }
        action('Open') { |shelf| open_books(shelf) }
      end
    end
  end
end
