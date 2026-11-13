# frozen_string_literal: true

module UI
  # The board's word in rubbs' block font, for both faces.
  module Logo
    WORD = 'SILICONIA'

    # Three rows of half blocks for a modern terminal.
    def self.half_blocks = Rubbs::Common::Text::BlockFont.half_blocks(WORD)

    # Five rows of reversed spaces, centred on the 40 columns of a C64.
    def self.petscii(colors)
      font = Rubbs::Common::Text::BlockFont
      font.petscii(WORD, colors: colors, indent: [(40 - font.width(WORD)) / 2, 0].max)
    end
  end
end
