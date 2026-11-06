# frozen_string_literal: true

require_relative 'pen'

module UI
  class Petscii < Rubbs::Petscii::Face
    # The 40×25 canvas on a C64 screen: 24 of its rows (the top 24 or the
    # bottom 24) and a status line on the last screen row, which is never
    # written to its last column, so the screen does not scroll.
    #
    # It remembers what it has drawn, so after a change it sends only the
    # cells that differ, with the shortest cursor moves (relative, or HOME
    # and down and right). Cursor moves go as ANSI, which the PETSCII line
    # turns into the C64's cursor codes; colours and reverse go as the C64's
    # own codes (Pen). At 1200 or 2400 baud every byte counts.
    class CanvasView
      COLS        = CanvasModel::COLS
      VIEW_ROWS   = 24
      STATUS_ROW  = 24
      STATUS_COLS = 39
      # Past this many changed cells a whole new screen is cheaper.
      REDRAW_AT = 320

      attr_reader :offset

      def initialize(session)
        @session = session
        @pen     = Pen.new
        @shown   = nil
        @offset  = 0
        @row     = nil
        @col     = nil
        @status  = nil
      end

      # Scrolls so that canvas row +y+ is on the screen; true when it had
      # to (the next sync draws the whole screen).
      def follow?(y)
        value = if y < @offset then y
                elsif y >= @offset + VIEW_ROWS then y - VIEW_ROWS + 1
                else @offset
                end
        return false if value == @offset

        @offset = value
        @shown  = nil
        true
      end

      # Clears the screen and draws +canvas+ row by row.
      def redraw(canvas)
        out = "#{Rubbs::Modern::Ansi::RESET}#{Rubbs::Petscii::CLEAR}#{Rubbs::Petscii::RVS_OFF}"
        @pen.reset
        @pen.rvs_off!
        @shown = Array.new(VIEW_ROWS * COLS)
        VIEW_ROWS.times do |sr|
          cells = screen_row(canvas, sr)
          @shown[sr * COLS, COLS] = cells
          out << @pen.row(cells, COLS)
        end
        @row    = STATUS_ROW
        @col    = 0
        @status = nil
        @session.write(out)
      end

      # Draws the cells of +canvas+ that differ from the screen.
      def sync(canvas)
        return redraw(canvas) unless @shown

        changed = changes(canvas)
        return if changed.empty?
        return redraw(canvas) if changed.size > REDRAW_AT

        out = +''
        changed.each do |sr, x, cell|
          out << goto(sr, x) << @pen.cell(*cell)
          @shown[(sr * COLS) + x] = cell
          advance(1)
        end
        @session.write(out)
      end

      # Writes +runs+ ([[text, colour, reversed], …], at most 39 characters
      # in all) on the status line, when it differs from what is there.
      def status(runs)
        return if runs == @status

        length = runs.sum { |text, _| text.length }
        old    = @status ? @status.sum { |text, _| text.length } : STATUS_COLS
        out = +goto(STATUS_ROW, 0)
        runs.each { |text, color, rvs| out << @pen.cell('', color, rvs || false) << text }
        out << @pen.cell('', nil, false)
        out << (' ' * (old - length)) if old > length
        @session.write(out)
        advance([length, old].max)
        @status = runs
      end

      # Puts the C64's cursor on canvas cell +x+, +y+.
      def place(x, y) = @session.write(goto(y - @offset, x))

      # Forgets the screen: the next sync draws it whole.
      def forget! = (@shown = nil)

      private

      # Screen row +sr+ of +canvas+ as C64 cells.
      def screen_row(canvas, sr) = COLS.times.map { |x| Pen.canvas(*canvas.at(x, @offset + sr)) }

      # The cells that differ from the screen: [[screen row, x, cell], …].
      def changes(canvas)
        VIEW_ROWS.times.flat_map do |sr|
          screen_row(canvas, sr).each_with_index.filter_map do |cell, x|
            [sr, x, cell] unless @shown[(sr * COLS) + x] == cell
          end
        end
      end

      def goto(row, col)
        return '' if row == @row && col == @col

        relative = @row ? (row - @row).abs + (col - @col).abs : Float::INFINITY
        out = if relative <= row + col + 1
                vertical(row - @row) + horizontal(col - @col)
              else
                "\e[#{row + 1};#{col + 1}H"
              end
        @row = row
        @col = col
        out
      end

      def vertical(delta)
        return '' if delta.zero?

        delta.positive? ? "\e[#{delta}B" : "\e[#{-delta}A"
      end

      def horizontal(delta)
        return '' if delta.zero?

        delta.positive? ? "\e[#{delta}C" : "\e[#{-delta}D"
      end

      def advance(count)
        @col += count
        return unless @col >= COLS

        @row += @col / COLS
        @col %= COLS
      end
    end
  end
end
