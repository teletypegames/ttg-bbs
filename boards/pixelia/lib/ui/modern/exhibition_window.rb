# frozen_string_literal: true

module UI
  module Modern
    # The Exhibition: the works on the left, the picked one's picture on the
    # right; Upload takes a TTG Canvas 64 picture by XMODEM.
    module ExhibitionWindow
      extend Rubbs::Modern::Part

      window :exhibition, :master_detail do
        title 'The Exhibition'
        empty 'Nothing on the Exhibition yet: paint on the canvas and save it.'
        list_width { [24, cols - 46].max }
        items      { works }
        label      :title
        detail     { |work, width| [bright(work.title), "#{accent(work.handle)} · #{work.date}", '', *preview(work, width)] }
        meta       { |work| "##{work.id}" }
        on_pick    { |work| view_work(work) }
        height(-6)
        action('View') { |work| view_work(work) }
        action('Upload') { upload_to_exhibition }
        action('Reload') { window.replace_items(exhibition.all) }
      end

      helpers do
        def preview(work, width)
          shown = [width - 1, CanvasModel::COLS].min
          return work.petscii.then { |p| PetsciiModel::ROWS.times.map { |y| ArtLines.petscii(p, y, 0, shown) } } if work.petscii?

          picture = work.canvas
          CanvasModel::ROWS.times.map { |y| ArtLines.canvas(picture, y, 0, shown) }
        end
      end
    end
  end
end
