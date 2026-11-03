# frozen_string_literal: true

module UI
  module Modern
    # A list of episodes, of a series or of this day: the codes and titles
    # on the left, the picked one's card on the right; Enter reads its
    # Memory Alpha article.
    module EpisodesWindow
      module_function

      def install(app)
        app.window(:episodes, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         { |ctx| " #{ctx[:title]} " }
        w.list_width    { |ctx| [40, ctx[:app].cols * 2 / 5].max }
        w.items         { |ctx| ctx[:entries] }
        w.item_label    { |entry, ctx| label(*entry, ctx[:years]) }
        w.empty_message 'No episodes in the catalog.'
        w.render_detail { |(e, s), width, ctx| detail(e, s, width, ctx[:app]) }
        w.bottom_meta   { |_entry, _ctx| 'Enter reads its Memory Alpha article' }
        actions(w)
      end

      def actions(w)
        w.on_activate { |(e, _s), _window, ctx| ctx[:app].read_episode(e) }
        w.action(label: '&Read') do |win, ctx|
          entry = win.list_widget.selected_item
          ctx[:app].read_episode(entry.first) if entry
          :keep
        end
      end

      def label(episode, series, years) = years ? "#{episode.year} #{series.abbreviation} #{episode.label}" : episode.label

      def detail(episode, series, width, app)
        t = app.theme
        ["#{t[:text_bright]}#{episode.title}#{t[:text]}", '', *app.card(Card.episode(episode, series), width)]
      end
    end
  end
end
