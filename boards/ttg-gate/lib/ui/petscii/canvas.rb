# frozen_string_literal: true

module UI
  module Petscii
    # The C64 screen as a grid of cells in the uppercase/graphics character
    # set, where the card suits, the balls, the rounded corners, the
    # diagonals and the quarter blocks live. It turns into raw PETSCII: the
    # whole screen once, then only the spans that change, because a C64 line
    # behind a modem is slow. It bypasses the PETSCII encoder of rubbs, which
    # speaks the lowercase set.
    class Canvas
      ROWS = 25
      COLS = 40

      # The PETSCII colour codes.
      WHITE       = 0x05
      RED         = 0x1c
      GREEN       = 0x1e
      BLUE        = 0x1f
      ORANGE      = 0x81
      BROWN       = 0x95
      LIGHT_RED   = 0x96
      DARK_GREY   = 0x97
      GREY        = 0x98
      LIGHT_GREEN = 0x99
      LIGHT_BLUE  = 0x9a
      LIGHT_GREY  = 0x9b
      PURPLE      = 0x9c
      YELLOW      = 0x9e
      CYAN        = 0x9f

      CLEAR     = 0x93
      HOME      = 0x13
      DOWN      = 0x11
      RIGHT     = 0x1d
      RVS_ON    = 0x12
      RVS_OFF   = 0x92
      CR        = 0x0d
      UPPERCASE = 0x8e
      LOWERCASE = 0x0e

      # The graphics of the uppercase set by the Unicode character they look
      # like; GLYPHS_REVERSED are the same codes in reverse video.
      GLYPHS = {
        '─' => 0xc0, '│' => 0xdd, '┼' => 0xdb, '╭' => 0xd5, '╮' => 0xc9, '╰' => 0xca, '╯' => 0xcb,
        '●' => 0xd1, '○' => 0xd7, '♥' => 0xd3, '♠' => 0xc1, '♣' => 0xd8, '♦' => 0xda, 'π' => 0xde,
        '╲' => 0xcd, '╱' => 0xce, '╳' => 0xd6, '◤' => 0xa9, '◥' => 0xdf,
        '▌' => 0xa1, '▄' => 0xa2, '▔' => 0xa3, '▁' => 0xa4, '▒' => 0xa6,
        '▖' => 0xbb, '▗' => 0xac, '▘' => 0xbe, '▝' => 0xbc, '▚' => 0xbf, '£' => 0x5c
      }.freeze
      GLYPHS_REVERSED = { '█' => 0x20, '▀' => 0xa2, '◢' => 0xa9, '◣' => 0xdf, '▐' => 0xa1 }.freeze

      Cell = Struct.new(:code, :color, :rvs)

      def initialize
        @cells = Array.new(ROWS) { Array.new(COLS) { blank } }
      end

      # Writes +text+ from +row+, +col+ in +color+; a character of
      # GLYPHS_REVERSED, or every one with +rvs+, in reverse video. Cells off
      # the screen, and the last cell of the last row (printing there
      # scrolls the C64 screen), are left out.
      def text(row, col, text, color, rvs: false)
        text.each_char.with_index do |ch, i|
          c = col + i
          next unless inside?(row, c)

          code, reversed = Canvas.code(ch)
          @cells[row][c] = Cell.new(code, color, rvs ^ reversed)
        end
        self
      end

      def clear(row, col, width)
        width.times { |i| @cells[row][col + i] = blank if inside?(row, col + i) }
        self
      end

      # The whole screen: the graphics set, a clear screen, then the rows,
      # each cut after its last visible cell.
      def frame
        out = [UPPERCASE, CLEAR]
        state = { color: nil, rvs: false }
        last = ROWS - 1
        last -= 1 while last.positive? && visible_end(last).zero?
        (0..last).each do |row|
          len = visible_end(row)
          emit(out, @cells[row].first(len), state)
          next if len == COLS || row == last

          out << CR
          state[:rvs] = false
        end
        out.pack('C*')
      end

      # The cells of +row+ from +col+, +width+ long, with the cursor moves
      # that put them in place.
      def span(row, col, width)
        out = [HOME] + ([DOWN] * row) + ([RIGHT] * col)
        state = { color: nil, rvs: false }
        out << RVS_OFF
        emit(out, @cells[row][col, width], state)
        out << RVS_OFF if state[:rvs]
        out.pack('C*')
      end

      # The cursor moves to +row+, +col+, with nothing printed.
      def cursor(row, col) = ([HOME] + ([DOWN] * row) + ([RIGHT] * col)).pack('C*')

      # The PETSCII code of +ch+ in the uppercase set, and whether it is a
      # reversed glyph; '?' for a character it does not have.
      def self.code(ch)
        return [GLYPHS_REVERSED[ch], true] if GLYPHS_REVERSED.key?(ch)
        return [GLYPHS[ch], false] if GLYPHS.key?(ch)

        o = ch.upcase.ord
        o.between?(0x20, 0x5d) ? [o, false] : ['?'.ord, false]
      end

      private

      def blank = Cell.new(0x20, nil, false)

      def inside?(row, col) = row.between?(0, ROWS - 1) && col.between?(0, COLS - 1) && !(row == ROWS - 1 && col == COLS - 1)

      def visible_end(row)
        cells = @cells[row]
        len = cells.size
        len -= 1 while len.positive? && cells[len - 1].code == 0x20 && !cells[len - 1].rvs
        len
      end

      def emit(out, cells, state)
        cells.each do |cell|
          visible = cell.code != 0x20 || cell.rvs
          if visible && cell.color && cell.color != state[:color]
            out << cell.color
            state[:color] = cell.color
          end
          if cell.rvs != state[:rvs] && (visible || state[:rvs])
            out << (cell.rvs ? RVS_ON : RVS_OFF)
            state[:rvs] = cell.rvs
          end
          out << cell.code
        end
      end
    end
  end
end
