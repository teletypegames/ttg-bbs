# frozen_string_literal: true

# The Unicode character a C64 screen code looks like, for a PETSCII work on
# a modern terminal. rubbs' tables (Rubbs::Petscii::Canvas.look, built on
# Rubbs::Petscii::Glyphs) give the letters, the signs and the graphics a
# terminal font has; the graphics they leave out (eighth lines, the corner
# pieces, the half shades) get the nearest character every terminal font
# has here: a line at another height is a line, a shade a shade. The
# reverse bit is not the character's: the faces draw it as swapped colours.
module PetsciiGlyphModel
  # What the uppercase/graphics set shows by PETSCII code, where rubbs has
  # no look-alike.
  UPPER = {
    0xa0 => ' ',
    0xa5 => '▏',
    0xa7 => '▕',
    0xa8 => '▒',
    0xaa => '▕',
    0xaf => '▂',
    0xb4 => '▎',
    0xb5 => '▍',
    0xb6 => '▐',
    0xb7 => '▔',
    0xb8 => '▀',
    0xb9 => '▃',
    0xba => '┘',
    0xc2 => '│',
    0xc3 => '─',
    0xc4 => '─',
    0xc5 => '─',
    0xc6 => '─',
    0xc7 => '│',
    0xc8 => '│',
    0xcc => '└',
    0xcf => '┌',
    0xd0 => '┐',
    0xd2 => '─',
    0xd4 => '│',
    0xd9 => '│',
    0xdc => '▒'
  }.freeze
  # The lower/upper set: UPPER but where the set has letters, and its own
  # shades in place of π, ◥ and ◤.
  LOWER = UPPER.except(0xba).merge(0xa9 => '▒', 0xde => '▒', 0xdf => '▒').freeze

  # The character the screen code +code+ looks like in +charset+ (+:upper+
  # or +:lower+).
  def self.look(code, charset)
    petscii = PetsciiModel.petscii(code)
    table = charset == :lower ? LOWER : UPPER
    return table[petscii] if table.key?(petscii)

    look = Rubbs::Petscii::Canvas.look(petscii, charset)
    look == '?' && petscii != 0x3f ? ' ' : look
  end
end
