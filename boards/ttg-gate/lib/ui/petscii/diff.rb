# frozen_string_literal: true

require_relative 'canvas'

module UI
  module Petscii
    # The bytes that repaint the changed cells of a Canvas, row by row from
    # the top: in a row the cursor steps right over the cells that stay, and
    # to the next row it goes the cheaper way, straight there or from HOME.
    # Cheaper than Canvas#patch for the blocks of text a view changes (that
    # one walks to the nearest cell, which on a row of text is often the one
    # to the left).
    module Diff
      module_function

      # +positions+ are [row, col] each. A binary String.
      def patch(canvas, positions)
        out = [Canvas::HOME, Canvas::RVS_OFF]
        state = { color: nil, rvs: false }
        at = [0, 0]
        positions.group_by(&:first).sort.each do |row, cells|
          cells.map(&:last).sort.each do |col|
            out.concat(steps(at, row, col))
            emit(out, canvas.cell(row, col), state)
            at = col == Canvas::COLS - 1 ? [row + 1, 0] : [row, col + 1]
          end
        end
        out << Canvas::RVS_OFF if state[:rvs]
        out.pack('C*')
      end

      def steps(from, row, col)
        dr = row - from[0]
        dc = col - from[1]
        straight = (dr.negative? ? [Canvas::UP] * -dr : [Canvas::DOWN] * dr) +
                   (dc.negative? ? [Canvas::LEFT] * -dc : [Canvas::RIGHT] * dc)
        home = [Canvas::HOME] + ([Canvas::DOWN] * row) + ([Canvas::RIGHT] * col)
        home.size < straight.size ? home : straight
      end

      def emit(out, cell, state)
        visible = cell.code != Canvas::SPACE || cell.rvs
        if visible && cell.color && cell.color != state[:color]
          out << cell.color
          state[:color] = cell.color
        end
        if cell.rvs != state[:rvs] && (visible || state[:rvs])
          out << (cell.rvs ? Canvas::RVS_ON : Canvas::RVS_OFF)
          state[:rvs] = cell.rvs
        end
        out << cell.code
      end
    end
  end
end
