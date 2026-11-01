# frozen_string_literal: true

module UI
  # WARP in the block font of rubbs (BBS::BlockFont), for both faces: half
  # blocks on a modern terminal, reversed spaces on a Commodore 64.
  module Logo
    WORD = 'WARP'

    # Three rows of half blocks.
    def self.half_blocks = BBS::BlockFont.half_blocks(WORD)
  end
end
