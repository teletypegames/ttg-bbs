# frozen_string_literal: true

module UI
  # The board's word in rubbs' block font, for both faces.
  module Logo
    WORD = 'STARBASE'

    # Three rows of half blocks for a modern terminal.
    def self.half_blocks = BBS::BlockFont.half_blocks(WORD)

    # Five rows of reversed spaces, centred on the 40 columns of a C64.
    def self.petscii(colors)
      BBS::BlockFont.petscii(WORD, colors: colors, indent: [(40 - BBS::BlockFont.width(WORD)) / 2, 0].max)
    end
  end
end
