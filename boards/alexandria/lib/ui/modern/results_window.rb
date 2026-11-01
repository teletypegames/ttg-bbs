# frozen_string_literal: true

module UI
  module Modern
    # The search results: the titles on the left, the picked one's snippet
    # on the right; Enter opens the article.
    module ResultsWindow
      module_function

      def install(app)
        app.window(:results, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         { |ctx| " Search: #{ctx[:query]} " }
        w.list_width    { |ctx| [30, ctx[:app].cols / 3].max }
        w.items         { |ctx| ctx[:results] }
        w.item_label    { |r, _ctx| r.title }
        w.render_detail { |r, width, ctx| detail(r, width, ctx[:app].theme) }
        w.bottom_meta   { |r, _ctx| "#{r.words} words · Enter opens it" }
        actions(w)
      end

      def actions(w)
        w.on_activate { |r, _window, ctx| ctx[:app].read(r.title) }
        w.action(label: '&Open') { |win, ctx| read_selected(win, ctx[:app]) }
      end

      def detail(result, width, t)
        ["#{t[:text_bright]}#{result.title}#{t[:text]}", '', *BBS::FrameBuffer.wrap_ansi("…#{result.snippet}…", width - 1)]
      end

      def read_selected(window, app)
        item = window.list_widget.selected_item
        app.read(item.title) if item
        :keep
      end
    end
  end
end
