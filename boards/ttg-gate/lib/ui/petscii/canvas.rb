# frozen_string_literal: true

module UI
  module Petscii
    # The 40×25 cell grid of the C64 face: rubbs' BBS::Petscii::Canvas in
    # the lower/upper character set, so text keeps its case. There a
    # lowercase letter is 0x41-0x5A and a capital 0xC1-0xDA, and the shifted
    # graphics that turn into capitals (the balls, the rounded corners, the
    # diagonals, π, ◤ ◥) are gone; the lines, the cross, the blocks, ▒ and
    # the 0xA0-0xBF graphics stay.
    class Canvas < BBS::Petscii::Canvas
      # The PETSCII codes the lower/upper set shows differently.
      CHANGED = [*0xc1..0xda, 0xde, 0xdf, 0xa9, 0xba].freeze
      LOWER_GLYPHS = GLYPHS.reject { |_, code| CHANGED.include?(code) }.freeze
      LOWER_REVERSED = GLYPHS_REVERSED.reject { |_, code| CHANGED.include?(code) }.freeze
      LOOKS = LOWER_GLYPHS.invert.merge(0x20 => ' ').freeze

      def self.code(ch)
        return [LOWER_REVERSED[ch], true] if LOWER_REVERSED.key?(ch)
        return [LOWER_GLYPHS[ch], false] if LOWER_GLYPHS.key?(ch)

        o = ch.ord
        return [o - 0x20, false] if ch.length == 1 && ch.between?('a', 'z')
        return [o + 0x80, false] if ch.length == 1 && ch.between?('A', 'Z')

        ASCII_SHOWN.include?(o) ? [o, false] : ['?'.ord, false]
      end

      def self.glyph?(ch)
        return true if LOWER_GLYPHS.key?(ch) || LOWER_REVERSED.key?(ch)

        ch.length == 1 && (ch.match?(/[a-z]/) || ASCII_SHOWN.include?(ch.ord))
      end

      def text(row, col, text, color, rvs: false)
        text.each_char.with_index do |ch, i|
          code, reversed = Canvas.code(ch)
          put(row, col + i, code, color, rvs: rvs ^ reversed)
        end
        self
      end

      # The whole screen, in the lower/upper set.
      def frame
        bytes = super
        bytes.setbyte(0, LOWERCASE)
        bytes
      end

      def to_s
        (0...ROWS).map do |row|
          (0...COLS).map { |col| look(cell(row, col).code) }.join.rstrip
        end.join("\n")
      end

      private

      def look(code)
        return LOOKS[code] if LOOKS.key?(code)
        return (code + 0x20).chr if code.between?(0x41, 0x5a)
        return (code - 0x80).chr if code.between?(0xc1, 0xda)

        code < 0x80 ? code.chr : '?'
      end
    end
  end
end
