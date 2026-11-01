# frozen_string_literal: true

module UI
  module Modern
    # The Wall: the saved works on the left, the picked one's picture on
    # the right.
    module WallWindow
      module_function

      def install(app)
        app.window(:wall, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title ' The Wall '
        Pane.size(w) { |app| [24, app.cols - 46].max }
        w.items         { |ctx| ctx[:works] }
        w.item_label    { |work, _ctx| work.title }
        w.empty_message 'Nothing on the Wall yet: paint on the canvas and save it.'
        w.render_detail { |work, width, ctx| detail(work, width, ctx[:app].theme) }
        w.bottom_meta   { |work, _ctx| "##{work.id}" }
        w.on_activate   { |work, _window, ctx| ctx[:app].view_work(work) }
        actions(w)
      end

      def actions(w)
        w.action(label: '&View') { |win, ctx| ctx[:app].with_selected(win) { |work| ctx[:app].view_work(work) } }
        w.action(label: '&Reload') do |win, ctx|
          win.replace_items(ctx[:app].wall.all)
          :keep
        end
      end

      def detail(work, width, t)
        picture = work.canvas
        ["#{t[:text_bright]}#{work.title}#{t[:text]}", "#{t[:accent]}#{work.handle}#{t[:text]} · #{work.date}", '',
         *CanvasModel::ROWS.times.map { |y| ArtLines.canvas(picture, y, 0, [width - 1, CanvasModel::COLS].min) }]
      end
    end
  end
end
