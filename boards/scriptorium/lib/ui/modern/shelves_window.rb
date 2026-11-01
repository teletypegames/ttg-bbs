# frozen_string_literal: true

module UI
  module Modern
    # The bookshelves of Project Gutenberg (and the Classics) on the left,
    # what a shelf is on the right; Enter opens its books.
    module ShelvesWindow
      def self.define(app)
        app.window(:shelves, type: :master_detail) do |w|
          frame(w)
          list(w)
          w.action(label: '&Open') { |win, ctx| open_selected(win, ctx[:app]) }
        end
      end

      def self.frame(w)
        w.maximizable true
        w.title         ' Bookshelves '
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [34, (ctx[:app].cols / 2) - 4].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:shelves] }
        w.item_label    { |s, _ctx| s.label }
        w.empty_message 'No bookshelves yet.'
        w.render_detail { |s, width, ctx| detail(s, width, ctx[:app].theme) }
        w.bottom_meta { |_s, _ctx| 'Enter opens the shelf' }
        w.on_activate { |s, _window, ctx| ctx[:app].open_books(s) }
      end

      def self.open_selected(window, app)
        shelf = app.selected(window)
        app.open_books(shelf) if shelf
        :keep
      end

      def self.detail(shelf, width, t)
        ["#{t[:text_bright]}#{shelf.label}#{t[:text]}", "#{t[:accent]}#{shelf.count} books#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi(kind(shelf), width - 1), '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}The first #{LibraryService::SHELF_LIMIT} by ebook number " \
                                     "are listed: the oldest ebooks are the best known ones.#{t[:text]}", width - 1)]
      end

      def self.kind(shelf)
        if shelf.classics? then 'The board\'s own shelf of well-known books.'
        elsif shelf.category? then 'A category of Project Gutenberg.'
        else 'A bookshelf of Project Gutenberg, gathered by its volunteers.'
        end
      end
    end
  end
end
