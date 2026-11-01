# frozen_string_literal: true

module UI
  # COMMODEX in blocks, five rows of a 3×5 font, for both faces: half blocks
  # on a modern terminal, reversed spaces on a Commodore 64.
  module Logo
    WORD = 'COMMODEX'
    FONT = {
      'C' => %w[### #.. #.. #.. ###], 'O' => %w[### #.# #.# #.# ###],
      'M' => %w[#.# ### ### #.# #.#], 'D' => %w[##. #.# #.# #.# ##.],
      'E' => %w[### #.. ##. #.. ###], 'X' => %w[#.# #.# .#. #.# #.#]
    }.freeze
    HALF = { [true, true] => '█', [true, false] => '▀', [false, true] => '▄', [false, false] => ' ' }.freeze

    # The rows of the word, '#' for a block, '.' for a space.
    def self.rows = 5.times.map { |row| WORD.chars.map { |c| FONT[c][row] }.join('.') }

    # Three rows of half blocks: the five rows two by two.
    def self.half_blocks
      bits = rows.map { |r| r.chars.map { |c| c == '#' } }
      bits << Array.new(bits.first.size, false)
      bits.each_slice(2).map { |top, bottom| top.zip(bottom).map { |pair| HALF[pair] }.join }
    end
  end
end
