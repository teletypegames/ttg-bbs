# frozen_string_literal: true

module UI
  module Modern
    # The feed list: the feeds on the left, the one picked on the right.
    module FeedsWindow
      module_function

      def install(app)
        app.window(:feeds, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        TwoPane.size(w)
        w.title         ' Feeds '
        w.items         { |ctx| ctx[:feeds].list }
        w.item_label    { |f, _ctx| f.name }
        w.empty_message 'No feeds are configured.'
        w.render_detail { |f, width, ctx| detail(f, width, ctx[:app].theme) }
        w.bottom_meta   { |_f, _ctx| 'Enter opens the feed' }
        w.on_activate   { |f, _window, ctx| ctx[:app].open_feed(f) }
        w.action(label: '&Open') { |win, ctx| open_selected(win, ctx) }
      end

      def detail(feed, width, t)
        ["#{t[:text_bright]}#{feed.name}#{t[:text]}",
         "#{t[:accent]}#{[feed.group, feed.lang].reject(&:empty?).join(' · ')}#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi(feed.about, width - 1), '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{feed.url}#{t[:text]}", width - 1)]
      end

      def open_selected(win, ctx)
        feed = win.list_widget.selected_item
        ctx[:app].open_feed(feed) if feed
        :keep
      end
    end
  end
end
