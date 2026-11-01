# frozen_string_literal: true

module UI
  module Modern
    # The shelves window: the shelf list, a shelf's about and address on
    # the right; Enter opens its titles.
    module Shelves
      def self.define(app)
        app.window(:shelves, type: :master_detail) do |w|
          layout(w)
          behaviour(w)
        end
      end

      def self.layout(w)
        w.title         ' Shelves '
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
        w.items         { |ctx| ctx[:catalog].shelves }
        w.item_label    { |s, _ctx| s.name }
        w.empty_message 'No shelves are configured.'
        w.render_detail { |s, width, ctx| detail(s, width, ctx[:app]) }
      end

      def self.behaviour(w)
        w.bottom_meta { |_s, _ctx| 'Enter opens the shelf' }
        w.on_activate { |s, _window, ctx| ctx[:app].open_shelf(s) }
        w.action(label: '&Open') { |win, ctx| ctx[:app].with_selected(win) { |s| ctx[:app].open_shelf(s) } }
      end

      def self.detail(shelf, width, app)
        t = app.theme
        ["#{t[:text_bright]}#{shelf.name}#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi(shelf.about, width - 1), '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{app.catalog.url(shelf)}/#{t[:text]}", width - 1)]
      end
    end
  end
end
