# frozen_string_literal: true

module UI
  module Modern
    # The series and the films: the titles on the left, the picked one's
    # years and counts on the right; Enter opens its episodes.
    module SeriesWindow
      module_function

      def install(app)
        app.window(:series, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         ' Series '
        w.list_width    { |ctx| [34, ctx[:app].cols / 3].max }
        w.items         { |ctx| ctx[:app].catalog.series }
        w.item_label    { |s, _ctx| s.short_title }
        w.empty_message 'The catalog is empty.'
        w.render_detail { |s, width, ctx| detail(s, width, ctx[:app]) }
        w.bottom_meta   { |_s, _ctx| 'Enter opens the episodes' }
        actions(w)
      end

      def actions(w)
        w.on_activate { |s, _window, ctx| ctx[:app].open_series(s) }
        w.action(label: '&Episodes') { |win, ctx| with_selected(win) { |s| ctx[:app].open_series(s) } }
        w.action(label: '&Article') { |win, ctx| with_selected(win) { |s| ctx[:app].read(s.ma || s.title) } }
      end

      def detail(series, width, app)
        t        = app.theme
        episodes = app.catalog.episodes(series)
        ["#{t[:text_bright]}#{series.title}#{t[:text]}", '',
         *app.card(Card.series(series, episodes, app.catalog.seasons(series)), width)]
      end

      def with_selected(window)
        item = window.list_widget.selected_item
        yield item if item
        :keep
      end
    end
  end
end
