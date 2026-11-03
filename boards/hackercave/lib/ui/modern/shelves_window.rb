# frozen_string_literal: true

module UI
  module Modern
    # The shelves on the left (the board's own, the series, the statuses,
    # the decades, the newest), what a shelf is on the right; Enter opens
    # its RFCs.
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
        w.title         ' Shelves '
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [30, (ctx[:app].cols / 2) - 4].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:shelves] }
        w.item_label    { |s, _ctx| label(s) }
        w.empty_message 'No shelves yet.'
        w.render_detail { |s, width, ctx| detail(s, width, ctx[:app].theme) }
        w.bottom_meta { |_s, _ctx| 'Enter opens the shelf' }
        w.on_activate { |s, _window, ctx| ctx[:app].open_entries(s) }
      end

      def self.label(shelf) = shelf.kind == :series ? "#{shelf.name} series" : shelf.name

      def self.open_selected(window, app)
        shelf = app.selected(window)
        app.open_entries(shelf) if shelf
        :keep
      end

      def self.detail(shelf, width, t)
        ["#{t[:text_bright]}#{label(shelf)}#{t[:text]}", "#{t[:accent]}#{shelf.count} RFCs#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi(shelf.about, width - 1), '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{note(shelf)}#{t[:text]}", width - 1)]
      end

      def self.note(shelf)
        case shelf.kind
        when :curated then 'The board\'s own shelf.'
        when :status, :decade then "At most #{LibraryService::SHELF_LIMIT} are listed; search for the rest."
        else 'From the index of the RFC Editor.'
        end
      end
    end
  end
end
