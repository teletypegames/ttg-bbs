# frozen_string_literal: true

module UI
  # ALEXANDRIA in a 3×5 block font, five rows, for the PETSCII masthead
  # (reversed spaces). The modern desktop draws the name in its own
  # half-block font beside the Pharos (UI::Modern::Pharos).
  module Logo
    WORD = 'ALEXANDRIA'
    FONT = {
      'A' => %w[.#. #.# ### #.# #.#], 'L' => %w[#.. #.. #.. #.. ###], 'E' => %w[### #.. ##. #.. ###],
      'X' => %w[#.# #.# .#. #.# #.#], 'N' => %w[##. #.# #.# #.# #.#], 'D' => %w[##. #.# #.# #.# ##.],
      'R' => %w[##. #.# ##. #.# #.#], 'I' => %w[# # # # #]
    }.freeze

    # The rows of the word, '#' for a block, '.' for a space.
    def self.rows = 5.times.map { |row| WORD.chars.map { |c| FONT[c][row] }.join('.') }
  end
end
