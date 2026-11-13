# frozen_string_literal: true

module UI
  class Petscii < Rubbs::Petscii::Face
    # A machine's photo on a C64 screen of its own (UI::Picture's cells on a Canvas): the name on
    # top, the picture, its author and licence under it.
    module Photo
      private

      # The photo on a screen of its own: the picture, centred, its credit under it.
      def photo(machine)
        say('asking wikimedia commons…', color: GR)
        found = pictures.picture(machine)
        return alert(Wording.picture(found)) if found.is_a?(Symbol)

        @session.write_raw(photo_screen(machine, found).frame + [Rubbs::Petscii::Canvas::LOWERCASE].pack('C*'))
        pause
      end

      def photo_screen(machine, picture)
        canvas = Rubbs::Petscii::Canvas.new(charset: :lower)
        canvas.text(0, 1, ascii(machine.name)[0, 38], Rubbs::Petscii::Canvas::WHITE)
        draw(canvas, picture.c64)
        credit = wrap(ascii("photo: #{picture.credit}"), 38).first(2)
        credit.each_with_index { |l, i| canvas.text(24 - credit.size + i, 1, l, Rubbs::Petscii::Canvas::GREY) }
        canvas
      end

      # The cells of +pixels+ from the second row, centred.
      def draw(canvas, pixels)
        left = [(40 - pixels.width) / 2, 0].max
        UI::Picture.c64_cells(pixels).each_with_index do |cells, row|
          cells.each_with_index { |(code, color, rvs), col| canvas.put(row + 1, left + col, code, color, rvs: rvs) }
        end
      end

      def ascii(text) = text.to_s.unicode_normalize(:nfkd).gsub(/[^\x20-\x7e]/, '')
    end
  end
end
