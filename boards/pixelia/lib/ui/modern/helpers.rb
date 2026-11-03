# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the gallery's windows, a piece
    # or a work on the whole screen, the canvas and saving it to the Wall.
    module Helpers
      NO_ANSWER = '16colo.rs did not answer. Try again later.'
      PIECE     = { too_big: 'This piece is too large for the board.', unavailable: NO_ANSWER }.freeze

      def open_years
        show(:years, years: loading('Reading 16colo.rs…', failed: NO_ANSWER) { gallery.years })
      end

      def open_year(year)
        show(:packs, year: year, packs: loading("Reading the packs of #{year.year}…", failed: NO_ANSWER) { gallery.packs(year) })
      end

      def open_pack(pack)
        show(:files, pack: pack, files: loading("Reading #{pack.name}…", failed: NO_ANSWER) { gallery.files(pack) })
      end

      def view_piece(file)
        art = loading("Fetching #{file.name}…") { gallery.piece(file) }
        return report(art, PIECE, title: 'Piece') if art.is_a?(Symbol)

        title = [file.name, file.credits].reject(&:empty?).join(' · ')
        with_line do |session|
          Viewer.run(session, width: art.width, height: art.height, title: title) { |y, x, w| ArtLines.art(art, y, x, w) }
        end
      end

      def view_work(work)
        picture = work.canvas
        with_line do |session|
          Viewer.run(session, width: CanvasModel::COLS, height: CanvasModel::ROWS,
                              title: "#{work.title} · #{work.handle} · #{work.date}") do |y, x, w|
            ArtLines.canvas(picture, y, x, w)
          end
        end
      end

      def open_canvas
        window = windows.grep(CanvasWindow).first
        return raise_window(window) if window

        show(CanvasWindow.new(self, canvas: canvas, who: session_id, on_save: -> { save_to_wall }))
      end

      def save_to_wall
        wait = wall.wait(caller_key)
        return message(WallText.wait(wait), title: 'The Wall') if wait.positive?
        return message(WallText.result(:blank_canvas), title: 'The Wall') if canvas.snapshot.empty?

        show(:save_work, handle: context[:handle].to_s)
      end

      def open_wall = show(:wall, works: wall.all)
    end
  end
end
