# frozen_string_literal: true

module UI
  module Modern
    # The search results: the titles on the left, the picked one's size on
    # the right; Enter opens the article.
    module ResultsWindow
      module_function

      def install(app)
        app.window(:results, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         { |ctx| " Library computer: #{ctx[:query]} " }
        w.list_width    { |ctx| [34, ctx[:app].cols / 3].max }
        w.items         { |ctx| ctx[:results] }
        w.item_label    { |r, _ctx| r.title }
        w.render_detail { |r, width, ctx| detail(r, width, ctx[:app].theme) }
        w.bottom_meta   { |_r, _ctx| 'Enter opens the article' }
        actions(w)
      end

      def actions(w)
        w.on_activate { |r, _window, ctx| ctx[:app].read(r.title) }
        w.action(label: '&Open') do |win, ctx|
          item = win.list_widget.selected_item
          ctx[:app].read(item.title) if item
          :keep
        end
      end

      def detail(result, width, t)
        ["#{t[:text_bright]}#{result.title}#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{result.words} words on Memory Alpha#{t[:text]}", width - 1)]
      end
    end
  end
end
