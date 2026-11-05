# frozen_string_literal: true

module UI
  # SCRIPTORIUM in the block font of rubbs (Rubbs::Common::Text::BlockFont), the I one
  # column wide, 39 columns: it fits the 40 of a Commodore 64. Half blocks
  # on a modern terminal, reversed spaces on a C64.
  module Logo
    WORD = 'SCRIPTORIUM'
    GLYPHS = Rubbs::Common::Text::BlockFont::NARROW_I

    # Three rows of half blocks.
    def self.half_blocks = Rubbs::Common::Text::BlockFont.half_blocks(WORD, glyphs: GLYPHS)
  end
end
