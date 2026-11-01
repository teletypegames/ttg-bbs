# frozen_string_literal: true

module UI
  # FEEDIA, the masthead of both faces: a newspaper's name in half blocks
  # on a modern terminal (two rows, HALF_BLOCKS), and in a 3×5 block font
  # of reversed spaces on a Commodore 64 (five rows, rows).
  module Logo
    WORD = 'FEEDIA'
    HALF_BLOCKS = [
      '█▀▀ █▀▀ █▀▀ █▀▄ █ ▄▀█',
      '█▀  ██▄ ██▄ █▄▀ █ █▀█'
    ].freeze
    FONT = {
      'F' => %w[### #.. ##. #.. #..], 'E' => %w[### #.. ##. #.. ###], 'D' => %w[##. #.# #.# #.# ##.],
      'I' => %w[### .#. .#. .#. ###], 'A' => %w[.#. #.# ### #.# #.#]
    }.freeze

    # The rows of the word, '#' for a block, '.' for a space.
    def self.rows = 5.times.map { |row| WORD.chars.map { |c| FONT[c][row] }.join('.') }
  end
end
