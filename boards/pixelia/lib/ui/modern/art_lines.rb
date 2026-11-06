# frozen_string_literal: true

module UI
  module Modern
    # Rows of a piece or of the canvas as ANSI lines for a modern terminal:
    # an ANSI piece in the 16 ANSI colours (SGR 30-37 and 90-97, 40-47 and
    # 100-107 for the iCE bright backgrounds), the canvas in the xterm-256
    # colours of its C64 palette (ColorModel).
    module ArtLines
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
