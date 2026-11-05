# frozen_string_literal: true

module UI
  module Modern
    # The Wall: the saved works on the left, the picked one's picture on
    # the right.
    module WallWindow
      extend Rubbs::Modern::Part

      window :wall, :master_detail do
        title 'The Wall'
        empty 'Nothing on the Wall yet: paint on the canvas and save it.'
        list_width { [24, cols - 46].max }
        items      { works }
        label      :title
        detail     { |work, width| [bright(work.title), "#{accent(work.handle)} · #{work.date}", '', *preview(work, width)] }
        meta       { |work| "##{work.id}" }
        on_pick    { |work| view_work(work) }
        height(-6)
        action('View') { |work| view_work(work) }
        action('Reload') { window.replace_items(wall.all) }
      end

      helpers do
        def preview(work, width)
          picture = work.canvas
          CanvasModel::ROWS.times.map { |y| ArtLines.canvas(picture, y, 0, [width - 1, CanvasModel::COLS].min) }
        end
      end
    end
  end
end
