# frozen_string_literal: true

module UI
  # Charts in text: lines over time on a grid of dots (braille, 2×4 dots a
  # cell, on a modern terminal; half blocks, 1×2, on a C64), sparklines and
  # bars. Each returns lines of runs (UI::Paint).
  module Charts
    # The dots of a braille cell by [row][column].
    BRAILLE = [[0x01, 0x08], [0x02, 0x10], [0x04, 0x20], [0x40, 0x80]].freeze
    # The half blocks of a C64 cell by [top, bottom] dot.
    HALVES = { [false, false] => ' ', [true, false] => '▀', [false, true] => '▄', [true, true] => '█' }.freeze
    # A sparkline's steps on a modern terminal.
    SPARK = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇ █].freeze
    # A sparkline's steps on a C64.
    SPARK_C64 = ['▁', '▄', '█'].freeze
    # A bar's eighths on a modern terminal.
    EIGHTHS = ['', '▏', '▎', '▍', '▌', '▋', '▊', '▉'].freeze

    module_function

    # The dots of a cell on +face+: [columns, rows].
    def resolution(face) = face == :petscii ? [1, 2] : [2, 4]

    # Lines of +series+ (Visual::Series) on a grid +width+ × +height+ cells
    # over [+from+, +to+] (ms) and [+low+, +high+]; +stacked+ adds each
    # series on the ones before it.
    def plot(series, width:, height:, from:, to:, low:, high:, face:, stacked: false)
      cw, ch = resolution(face)
      grid = Grid.new(width * cw, height * ch)
      span = [to - from, 1].max.to_f
      tall = high > low ? (high - low).to_f : 1.0
      (stacked ? stack(series) : series.map { |s| [s, s.points] }).each do |s, points|
        dots = points.map { |at, v| [((at - from) / span * (grid.cols - 1)).round, ((v - low) / tall * (grid.rows - 1)).round] }
        grid.line_through(dots, s.color, gap: (grid.cols / 12.0).ceil + 1)
      end
      grid.cells(cw, ch) { |dots| face == :petscii ? HALVES.fetch(dots.map { |r| r[0] }) : braille(dots) }
    end

    # Each series' points with those of the series before it added (at the
    # same times).
    def stack(series)
      sums = Hash.new(0.0)
      series.map { |s| [s, s.points.map { |at, v| [at, sums[at] += v] }] }
    end

    # The braille character of a cell's +dots+ ([row][column] booleans).
    def braille(dots)
      code = dots.each_with_index.sum { |row, y| row.each_with_index.sum { |on, x| on ? BRAILLE[y][x] : 0 } }
      code.zero? ? ' ' : (0x2800 + code).chr(Encoding::UTF_8)
    end

    # A sparkline of +values+ in +width+ columns (the newest at the right).
    def spark(values, width, face)
      values = values.grep(Numeric).reject { |v| v.to_f.nan? }
      return '' if values.empty? || width <= 0

      values = squeeze(values, width)
      low, high = values.minmax
      steps = face == :petscii ? SPARK_C64 : SPARK
      values.map { |v| steps[high > low ? ((v - low) / (high - low) * (steps.size - 1)).round : 0] }.join
    end

    # +values+ made +width+ long by taking the largest of each stretch.
    def squeeze(values, width)
      return values if values.size <= width

      Array.new(width) { |i| values[(i * values.size / width)...((i + 1) * values.size / width)].max }
    end

    # A bar of +fraction+ (0–1) in +width+ columns.
    def bar(fraction, width, face)
      cells = fraction.to_f.clamp(0.0, 1.0) * width
      full  = cells.floor
      return ('█' * full) + (cells - full >= 0.5 && full < width ? '▌' : '') if face == :petscii

      ('█' * full) + EIGHTHS[((cells - full) * 8).floor.clamp(0, 7)]
    end

    # A grid of dots, each dot remembering the colour last drawn on it.
    class Grid
      # Its size in dots.
      attr_reader :cols, :rows

      # A grid of +cols+ × +rows+ dots.
      def initialize(cols, rows)
        @cols   = cols
        @rows   = rows
        @dots   = Array.new(rows) { Array.new(cols) }
      end

      # Draws lines through +points+ ([x, y], y from the bottom) in
      # +color+; points further apart than +gap+ columns are not joined.
      def line_through(points, color, gap:)
        points.each_cons(2) { |a, b| (b[0] - a[0]).abs <= gap ? line(a, b, color) : dot(*a, color) }
        dot(*points.last, color) if points.any?
      end

      # The cells of +cw+ × +ch+ dots: rows of runs, each cell's character
      # made by the block from its dots, in the colour of its last dot.
      def cells(cell_w, cell_h)
        (0...(@rows / cell_h)).map do |row|
          (0...(@cols / cell_w)).map do |col|
            block = (0...cell_h).map { |y| (0...cell_w).map { |x| @dots[(row * cell_h) + y][(col * cell_w) + x] } }
            color = block.flatten(1).compact.last
            [yield(block.map { |r| r.map { |c| !c.nil? } }), color || :line]
          end
        end
      end

      private

      def dot(x, y, color)
        return unless x.between?(0, @cols - 1) && y.between?(0, @rows - 1)

        @dots[@rows - 1 - y][x] = color
      end

      def line(from, to, color)
        x0, y0 = from
        x1, y1 = to
        steps = [(x1 - x0).abs, (y1 - y0).abs, 1].max
        (0..steps).each { |i| dot(x0 + ((x1 - x0) * i / steps.to_f).round, y0 + ((y1 - y0) * i / steps.to_f).round, color) }
      end
    end
  end
end
