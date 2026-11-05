# frozen_string_literal: true

module UI
  # PIXELIA in the block font of rubbs (Rubbs::Common::Text::BlockFont), each letter in a
  # colour of its own (C64 colours), for both faces: half blocks on a modern
  # terminal, reversed spaces on a Commodore 64.
  module Logo
    WORD = 'PIXELIA'
    # Light red, orange, yellow, light green, cyan, light blue, purple.
    COLORS = [10, 8, 7, 13, 3, 14, 4].freeze

    def self.width = Rubbs::Common::Text::BlockFont.width(WORD)

    # The five rows as runs: [[text, colour index or nil], …], '#' for a
    # block.
    def self.rows = 5.times.map { |row| runs { |c| Rubbs::Common::Text::BlockFont.glyph(c)[row] } }

    # Three rows of half blocks as runs.
    def self.half_blocks = 3.times.map { |row| runs { |c| Rubbs::Common::Text::BlockFont.half_blocks(c)[row] } }

    # A run a letter, the block's text and the letter's colour, with an
    # uncoloured space between the letters.
    def self.runs
      WORD.chars.each_with_index.flat_map do |c, i|
        [[yield(c), COLORS[i]], ([' ', nil] if i < WORD.length - 1)].compact
      end
    end
    private_class_method :runs
  end
end
