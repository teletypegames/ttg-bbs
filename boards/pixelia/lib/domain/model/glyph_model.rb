# frozen_string_literal: true

# The characters a cell of the canvas may hold: the ones a Unicode terminal
# and a Commodore 64 (its lowercase character set, through rubbs' PETSCII
# line) both show in one cell, so that the canvas looks the same on either.
# Letters, digits and most ASCII signs; the C64's box drawing, half blocks,
# checkerboard, eighth lines, check mark, pound and arrows.
#
# Left out: the double quote (it puts the C64's screen editor in quote mode),
# and \ ` { } ~, which the C64 has no glyph for.
module GlyphModel
  ASCII = [*' '..'!', *'#'..'[', ']', *'a'..'z'].freeze
  GRAPHICS = %w[─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ █ ▀ ▄ ▌ ▐ ▒ ▁ ▔ ✓ £ ← ↑].freeze
  ALLOWED = (ASCII + GRAPHICS).to_h { |c| [c, true] }.freeze

  # Look-alikes that become the glyph the C64 has.
  CANON = {
    '_' => '▁',
    '|' => '│',
    '^' => '↑',
    '░' => '▒',
    '▓' => '▒',
    '━' => '─',
    '═' => '─',
    '┃' => '│',
    '║' => '│',
    '╔' => '┌',
    '╭' => '┌',
    '╗' => '┐',
    '╮' => '┐',
    '╚' => '└',
    '╰' => '└',
    '╝' => '┘',
    '╯' => '┘',
    '╠' => '├',
    '╣' => '┤',
    '╦' => '┬',
    '╩' => '┴',
    '╬' => '┼',
    '✔' => '✓'
  }.freeze

  # The glyphs offered in the palettes of both faces, in their order.
  PALETTE = %w[█ ▀ ▄ ▌ ▐ ▒ ▁ ▔ ─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ ✓ £ ← ↑].freeze

  # +char+ as a canvas cell holds it, or nil when the canvas does not take it.
  def self.normalize(char)
    char = char.to_s
    return nil unless char.length == 1

    char = CANON.fetch(char, char)
    ALLOWED[char] ? char : nil
  end
end
