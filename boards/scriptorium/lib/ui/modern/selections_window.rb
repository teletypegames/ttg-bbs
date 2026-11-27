# frozen_string_literal: true

module UI
  module Modern
    # The bookshelves of Project Gutenberg (and the Classics) on the left,
    # what a selection is on the right; Enter opens its books.
    module SelectionsWindow
      extend Rubbs::Modern::Part

      KINDS = {
        classics:  "The board's own selection of well-known books.",
        category:  'A category of Project Gutenberg.',
        bookshelf: 'A bookshelf of Project Gutenberg, gathered by its volunteers.'
      }.freeze
      LISTED = "The first #{LibraryService::SELECTION_LIMIT} by ebook number are listed: " \
               'the oldest ebooks are the best known ones.'.freeze

      window :selections, :master_detail do
        title 'Bookshelves'
        height     { rows - 8 }
        list_width { [34, (cols / 2) - 4].min }
        items      { selections }
        label      :label
        empty 'No bookshelves yet.'
        detail do |selection|
          kind = if selection.classics? then :classics
                 elsif selection.category? then :category
                 else :bookshelf
                 end
          [bright(selection.label), accent("#{selection.count} books"), '', KINDS[kind], '', dim(LISTED)]
        end
        meta       { 'Enter opens the selection' }
        on_pick    { |selection| open_books(selection) }
        action('Open') { |selection| open_books(selection) }
      end
    end
  end
end
