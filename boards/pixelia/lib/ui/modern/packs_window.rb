# frozen_string_literal: true

module UI
  module Modern
    # The packs of a year on the left, the one picked on the right.
    module PacksWindow
      module_function

      def install(app)
        app.window(:packs, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title { |ctx| " 16colo.rs #{ctx[:year].year} " }
        Pane.size(w) { |app| [28, app.cols / 3].max }
        w.items         { |ctx| ctx[:packs] }
        w.item_label    { |p, _ctx| p.name }
        w.render_detail { |p, width, ctx| detail(p, width, ctx[:app]) }
        w.bottom_meta   { |_p, _ctx| 'Enter opens the pack' }
        w.on_activate   { |p, _window, ctx| ctx[:app].open_pack(p) }
      end

      def detail(pack, width, app)
        t = app.theme
        ["#{t[:text_bright]}#{pack.name}#{t[:text]}", "#{t[:accent]}#{pack.credits}#{t[:text]}",
         "#{t[:label]}#{pack.year}#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi("#{t[:text_dim]}#{app.gallery.pack_url(pack)}#{t[:text]}", width - 1)]
      end
    end
  end
end
