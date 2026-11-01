# frozen_string_literal: true

require_relative 'canvas'

module UI
  module Petscii
    # The grid every screen of the C64 face shares (40×25): the header on
    # row 0, the raster stripe on row 1, the main area (30 columns) and the
    # sidebar (9 columns) on rows 2 to 23 with a divider between them, the
    # hint bar on row 24. And the small drawing helpers of the views: runs of
    # coloured text, the title band, chips, rules.
    module Layout
      TOP        = 2
      ROWS       = 22
      BOTTOM     = TOP + ROWS - 1
      WIDTH      = 30
      DIVIDER    = 30
      SIDE       = 31
      SIDE_WIDTH = 9
      HINT_ROW   = 24
      # The C64 cannot print the last cell: the hint bar ends before it, and
      # the cursor rests there between two screens.
      HINT_WIDTH = Canvas::COLS - 1

      module_function

      # The main area's +line+ (0-based) as a screen row.
      def row(line) = TOP + line

      # Writes +parts+, [text, colour] or [text, colour, :rvs] each, from
      # +row+, +col+, cut at +limit+ (a column, exclusive). The column after
      # the last one written.
      def runs(canvas, row, col, parts, limit: WIDTH)
        parts.each do |text, color, rvs|
          text = text.to_s[0, [limit - col, 0].max]
          canvas.text(row, col, text, color, rvs: rvs == :rvs)
          col += text.length
        end
        col
      end

      # The title band of a screen: +title+ left and +right+ right, black on
      # +color+, the whole width of the main area.
      def band(canvas, title, right, color)
        right = right.to_s.empty? ? '' : "#{right} "
        canvas.text(TOP, 0, ' ' * WIDTH, color, rvs: true)
        canvas.text(TOP, 0, " #{title}"[0, WIDTH - right.length - 1], color, rvs: true)
        canvas.text(TOP, WIDTH - right.length, right, color, rvs: true)
      end

      # A thin rule across the main area.
      def rule(canvas, row) = canvas.text(row, 0, '─' * WIDTH, Canvas::DARK_GREY)

      # A chip: +text+ black on +color+ with a cell of air on each side. The
      # column after it.
      def chip(canvas, row, col, text, color, limit: WIDTH)
        text = " #{text} "
        return col if col + text.length > limit

        canvas.text(row, col, text, color, rvs: true)
        col + text.length
      end

      # +text+ in the letters and signs the lower/upper set has.
      def plain(text)
        text.to_s.each_char.map do |c|
          next c if Canvas.glyph?(c)

          near = BBS::Petscii.plain(c)
          near.each_char.all? { |n| Canvas.glyph?(n) } ? near : '?'
        end.join
      end

      # Draws the address +host+ (and +port+ after a colon, unless nil) from
      # +row+, +col+ whole: past +width+ it goes on at +col+ of the next
      # rows, broken after a dot or before the colon where it can be. The
      # number of rows it took.
      def address(canvas, row, col, host, port, width: WIDTH - col)
        host = plain(host)
        lines = split_address(port.nil? ? host : "#{host}:#{port}", width)
        offset = 0
        lines.each_with_index do |line, i|
          line.each_char.with_index do |ch, j|
            color = offset + j == host.length ? Canvas::DARK_GREY : Canvas::CYAN
            canvas.text(row + i, col + j, ch, color)
          end
          offset += line.length
        end
        lines.size
      end

      def split_address(text, width)
        lines = []
        while text.length > width
          cut = (1..width).select { |i| text[i - 1] == '.' || text[i] == ':' }.max || width
          lines << text[0, cut]
          text = text[cut..]
        end
        lines << text
      end

      # Lines of at most +width+ columns of +text+, at most +lines+ of them;
      # a cut one ends in dots.
      def wrap(text, width, lines)
        all = BBS::FrameBuffer.wrap_ansi(plain(text), width)
        return all if all.size <= lines

        shown = all.first(lines)
        shown[-1] = "#{shown[-1][0, width - 3].rstrip}..."
        shown
      end

      # "40m", "5h", "3d": how long ago +at+ was at +now+, short.
      def age(at, now)
        seconds = [now - at.to_i, 0].max
        return "#{seconds / 60}m" if seconds < 3600
        return "#{seconds / 3600}h" if seconds < 2 * 86_400

        "#{seconds / 86_400}d"
      end
    end
  end
end
