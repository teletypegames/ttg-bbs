# frozen_string_literal: true

module UI
  # Glyph mode on both faces: the letter keys paint the canvas' graphics
  # instead of themselves, laid out like the shapes on the keyboard (q w e /
  # a s d / z x c are the corners, tees and cross of a box). A C64's own
  # graphics keys (C= and Shift with a letter) do not reach the board, so
  # this is how a C64 draws boxes and blocks.
  module GlyphKeys
    MAP = {
      'q' => '┌', 'w' => '┬', 'e' => '┐', 'a' => '├', 's' => '┼', 'd' => '┤', 'z' => '└', 'x' => '┴', 'c' => '┘',
      'r' => '─', 'f' => '│', 't' => '▀', 'g' => '█', 'b' => '▄', 'y' => '▌', 'h' => '▐', 'u' => '▒',
      'i' => '▔', 'k' => '▁', 'o' => '✓', 'l' => '£', 'p' => '←', 'j' => '↑'
    }.freeze

    # The glyph +key+ paints in glyph mode, or +key+ itself.
    def self.glyph(key) = MAP.fetch(key.to_s.downcase, key)

    # The legend in rows of +per_row+: "q┌ w┬ e┐ …".
    def self.legend(per_row = 9) = MAP.map { |k, g| "#{k}#{g}" }.each_slice(per_row).map { |s| s.join(' ') }
  end
end
