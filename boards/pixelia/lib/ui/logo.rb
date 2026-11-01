# frozen_string_literal: true

module UI
  # PIXELIA in blocks, five rows of a 3×5 font, each letter in a colour of
  # its own (C64 colours), for both faces: half blocks on a modern terminal,
  # reversed spaces on a Commodore 64.
  module Logo
    WORD = 'PIXELIA'
    FONT = {
      'P' => %w[##. #.# ##. #.. #..], 'I' => %w[### .#. .#. .#. ###], 'X' => %w[#.# #.# .#. #.# #.#],
      'E' => %w[### #.. ##. #.. ###], 'L' => %w[#.. #.. #.. #.. ###], 'A' => %w[.#. #.# ### #.# #.#]
    }.freeze
    # Light red, orange, yellow, light green, cyan, light blue, purple.
    COLORS = [10, 8, 7, 13, 3, 14, 4].freeze
    HALF = { [true, true] => '█', [true, false] => '▀', [false, true] => '▄', [false, false] => ' ' }.freeze

    def self.width = (WORD.length * 4) - 1

    # The rows as runs: [[text, colour index or nil], …], '#' for a block.
    def self.rows
      5.times.map do |row|
        WORD.chars.each_with_index.flat_map do |c, i|
          [[FONT[c][row], COLORS[i]], ([' ', nil] if i < WORD.length - 1)].compact
        end
      end
    end

    # Three rows of half blocks, the five rows two by two, as runs.
    def self.half_blocks
      bits = rows
      bits << bits.first.map { |text, color| [text.tr('#', '.'), color] }
      bits.each_slice(2).map do |top, bottom|
        top.zip(bottom).map do |(t, color), (b, _)|
          [t.chars.zip(b.chars).map { |x, y| HALF[[x == '#', y == '#']] }.join, color]
        end
      end
    end
  end
end
