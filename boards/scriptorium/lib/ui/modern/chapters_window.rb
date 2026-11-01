# frozen_string_literal: true

module UI
  module Modern
    # The chapters of an open book on the left, the start of the one picked
    # on the right; Enter reads it in a ReaderWindow.
    module ChaptersWindow
      def self.define(app)
        app.window(:chapters, type: :master_detail) do |w|
          frame(w)
          list(w)
          w.action(label: '&Read') { |win, ctx| read(win, ctx) }
        end
      end

      def self.frame(w)
        w.maximizable true
        w.title         { |ctx| " #{ctx[:book].short_title[0, 50]} " }
        w.height        { |ctx| ctx[:app].rows - 8 }
        w.list_width    { |ctx| [40, (ctx[:app].cols / 2) - 4].min }
      end

      def self.list(w)
        w.items         { |ctx| ctx[:text].chapters }
        w.item_label    { |c, ctx| label(c, ctx[:text]) }
        w.empty_message 'No chapters.'
        w.render_detail { |c, width, ctx| detail(c, width, ctx) }
        w.bottom_meta { |_c, ctx| "eBook ##{ctx[:book].id} from Project Gutenberg · #{ctx[:book].url}" }
        w.on_activate { |c, _window, ctx| ctx[:app].read(ctx[:book], ctx[:text], c.number) }
      end

      # The number, right-aligned to the longest, and the title.
      def self.label(chapter, text) = "#{chapter.number.to_s.rjust(text.size.to_s.size)}. #{chapter.title}"

      def self.detail(chapter, width, ctx)
        t = ctx[:app].theme
        wrap = ->(s) { BBS::FrameBuffer.wrap_ansi(s, width - 1) }
        preview = ctx[:app].reading.preview(ctx[:text], chapter.number).to_s
        ["#{t[:text_bright]}#{chapter.title}#{t[:text]}", "#{t[:accent]}#{size(chapter, ctx[:text])}#{t[:text]}",
         '', *wrap.call("#{preview}…"), '', *wrap.call("#{t[:text_dim]}Enter reads it.#{t[:text]}")]
      end

      def self.size(chapter, text) = "Chapter #{chapter.number} of #{text.size} · #{(chapter.length / 1024.0).ceil} KB"

      def self.read(window, ctx)
        chapter = ctx[:app].selected(window)
        ctx[:app].read(ctx[:book], ctx[:text], chapter.number) if chapter
        :keep
      end
    end
  end
end
