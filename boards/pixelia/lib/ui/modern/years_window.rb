# frozen_string_literal: true

module UI
  module Modern
    # The years of 16colo.rs on the left, the one picked on the right.
    module YearsWindow
      ABOUT = '16colo.rs keeps the art packs of the ANSI and ASCII scene, year by year, as the groups released ' \
              'them. Pixelia reads them from its public API and draws each piece here, in its 16 colours.'

      module_function

      def install(app)
        app.window(:years, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title ' 16colo.rs '
        Pane.size(w, maximizable: false) { 24 }
        w.items         { |ctx| ctx[:years] }
        w.item_label    { |y, _ctx| "#{y.year}  #{y.packs.to_s.rjust(4)} packs" }
        w.render_detail { |y, width, ctx| detail(y, width, ctx[:app]) }
        w.bottom_meta   { |_y, _ctx| 'Enter opens the year' }
        w.on_activate   { |y, _window, ctx| ctx[:app].open_year(y) }
      end

      def detail(year, width, app)
        t = app.theme
        ["#{t[:text_bright]}#{year.year}#{t[:text]}", "#{t[:accent]}#{year.packs} art packs#{t[:text]}", '',
         *BBS::FrameBuffer.wrap_ansi(ABOUT, width - 1), '',
         "#{t[:text_dim]}#{app.gallery.site_url}/year/#{year.year}#{t[:text]}"]
      end
    end
  end
end
