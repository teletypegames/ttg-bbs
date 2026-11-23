# frozen_string_literal: true

module UI
  module Modern
    # Rows of a piece or of the canvas as ANSI lines for a modern terminal:
    # an ANSI piece in the 16 ANSI colours (SGR 30-37 and 90-97, 40-47 and
    # 100-107 for the iCE bright backgrounds), the canvas in the xterm-256
    # colours of its C64 palette (ColorModel), a PETSCII work in them too,
    # each screen code as the character it looks like (PetsciiGlyphModel), a
    # reversed one with ink and background swapped, framed in its border
    # colour on the whole screen.
    module ArtLines
      # The columns and rows of the border around a PETSCII work.
      BORDER_COLS = 2
      BORDER_ROWS = 1
      # The size of a PETSCII work in its border.
      FRAMED_COLS = PetsciiModel::COLS + (2 * BORDER_COLS)
      FRAMED_ROWS = PetsciiModel::ROWS + (2 * BORDER_ROWS)

      def self.ansi_sgr(fg, bg)
        f = fg < 8 ? 30 + fg : 82 + fg
        b = bg < 8 ? 40 + bg : 92 + bg
        "\e[0;#{f};#{b}m"
      end

      def self.canvas_sgr(fg, bg) = "\e[0;38;5;#{ColorModel[fg].xterm};48;5;#{ColorModel[bg].xterm}m"

      # Row +y+ of the ArtModel +art+ from column +x+, +width+ cells.
      def self.art(art, y, x, width) = line(art.cells(y, x, width)) { |fg, bg| ansi_sgr(fg, bg) }

      # Row +y+ of the CanvasModel +canvas+.
      def self.canvas(canvas, y, x = 0, width = CanvasModel::COLS)
        cells = (x...[x + width, CanvasModel::COLS].min).map { |cx| canvas.at(cx, y) }
        line(cells) { |fg, bg| canvas_sgr(fg, bg) }
      end

      # Row +y+ of the PetsciiModel +work+ from column +x+, +width+ cells.
      def self.petscii(work, y, x = 0, width = PetsciiModel::COLS)
        cells = (x...[x + width, PetsciiModel::COLS].min).map { |cx| petscii_cell(work, cx, y) }
        line(cells) { |fg, bg| canvas_sgr(fg, bg) }
      end

      # Row +y+ of the PetsciiModel +work+ in its border (FRAMED_COLS by
      # FRAMED_ROWS) from column +x+, +width+ cells.
      def self.petscii_framed(work, y, x, width)
        border = [' ', work.border, work.border]
        cells = (x...[x + width, FRAMED_COLS].min).map do |cx|
          px = cx - BORDER_COLS
          py = y - BORDER_ROWS
          inside = px.between?(0, PetsciiModel::COLS - 1) && py.between?(0, PetsciiModel::ROWS - 1)
          inside ? petscii_cell(work, px, py) : border
        end
        line(cells) { |fg, bg| canvas_sgr(fg, bg) }
      end

      # A cell of a PETSCII work: [char, fg, bg].
      def self.petscii_cell(work, x, y)
        code, color = work.at(x, y)
        char = PetsciiGlyphModel.look(code, work.charset)
        code >= PetsciiModel::REVERSE ? [char, work.background, color] : [char, color, work.background]
      end

      def self.line(cells)
        out  = +''
        last = nil
        cells.each do |char, fg, bg|
          sgr = yield(fg, bg)
          out << sgr unless sgr == last
          last = sgr
          out << char
        end
        out << "\e[0m"
      end
    end
  end
end
