# frozen_string_literal: true

module UI
  # HACKERCAVE in the block font of rubbs (BBS::BlockFont), 39 columns: it
  # fits the 40 of a Commodore 64. Half blocks on a modern terminal,
  # reversed spaces on a C64.
  module Logo
    WORD = 'HACKERCAVE'

    # Three rows of half blocks.
    def self.half_blocks = BBS::BlockFont.half_blocks(WORD)
  end
end
