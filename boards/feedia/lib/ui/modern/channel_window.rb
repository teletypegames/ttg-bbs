# frozen_string_literal: true

module UI
  module Modern
    # One feed: its items on the left, the text of the one picked on the
    # right, its address under it.
    module ChannelWindow
      module_function

      def install(app)
        app.window(:channel, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        TwoPane.size(w)
        w.title         { |ctx| " #{ctx[:channel].title} " }
        w.items         { |ctx| ctx[:channel].items }
        w.item_label    { |item, _ctx| item.title }
        w.empty_message 'This feed has nothing in it right now.'
        w.render_detail { |item, width, ctx| detail(item, width, ctx[:app]) }
        w.bottom_meta   { |item, _ctx| item.link.to_s }
        actions(w)
      end

      def actions(w)
        w.action(label: '&QR code') do |win, ctx|
          ctx[:app].show_qr(win.list_widget.selected_item)
          :keep
        end
        w.action(label: '&Reload') do |win, ctx|
          ctx[:app].reload(win, ctx[:channel])
          :keep
        end
      end

      def detail(item, width, app)
        t     = app.theme
        lines = app.markdown("# #{item.title}", width)
        lines << "#{t[:text_dim]}#{byline(item)}#{t[:text]}" unless byline(item).empty?
        lines << ''
        lines.concat(app.markdown(item.markdown.empty? ? '*(no text in the feed)*' : item.markdown, width))
      end

      def byline(item) = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' · ')
    end
  end
end
