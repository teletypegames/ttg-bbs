# frozen_string_literal: true

module UI
  # TTG WIKI in blocks, five rows of a 3×5 (W: 5×5) font. The Commodore 64
  # draws it in reversed spaces; the modern face has its FIGlet banner.
  module Logo
    WORDS = %w[TTG WIKI].freeze
    FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'G' => %w[### #.. #.# #.# ###],
      'W' => %w[#...# #...# #.#.# ##.## #...#], 'I' => %w[### .#. .#. .#. ###],
      'K' => %w[#.# #.# ##. #.# #.#]
    }.freeze

    # The rows of the words, '#' for a block, '.' for a space.
    def self.rows
      5.times.map do |row|
        WORDS.map { |word| word.chars.map { |c| FONT[c][row] }.join('.') }.join('...')
      end
    end
  end
end
