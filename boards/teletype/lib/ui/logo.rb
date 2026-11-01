# frozen_string_literal: true

module UI
  # The board's one logo, on every face: TTG BBS in the three-by-five pixel
  # font of rubbs (BBS::BlockFont, the font of the TTG Blog BBS masthead), in the
  # yellow to red of the logon art. The modern face draws two pixel rows in
  # a row of half blocks, the C64 one a pixel row as a row of reversed spaces.
  module Logo
    TEXT = 'TTG BBS'

    # The rows of the half-block logo, yellow, orange and red, as on the logon art.
    MODERN_COLORS = ["\e[1;33m", "\e[38;5;208m", "\e[1;31m"].freeze

    def self.width = BBS::BlockFont.width(TEXT)

    # Three rows of half blocks with ANSI colours, each as wide as the logo.
    def self.half_blocks = BBS::BlockFont.half_blocks(TEXT, colors: MODERN_COLORS)
  end
end
