# frozen_string_literal: true

module UI
  # The board's one logo, on every face: TTG BBS in a three-by-five pixel
  # font (the font of the TTGBLOG masthead), in the yellow to red of the logon
  # art. The modern face draws two pixel rows in a row of half blocks, the
  # C64 one a pixel row as a row of reversed spaces.
  module Logo
    TEXT = 'TTG BBS'

    FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'G' => %w[### #.. #.# #.# ###], 'B' => %w[##. #.# ##. #.# ##.],
      'S' => %w[### #.. ### ..# ###], ' ' => %w[. . . . .]
    }.freeze

    HALF_BLOCKS = { '##' => '█', '#.' => '▀', '.#' => '▄', '..' => ' ' }.freeze

    # The rows of the half-block logo, yellow, orange and red, as on the logon art.
    MODERN_COLORS = ["\e[1;33m", "\e[38;5;208m", "\e[1;31m"].freeze

    # Five pixel rows, # set and . clear.
    def self.bits(text = TEXT)
      5.times.map { |row| text.chars.map { |c| FONT.fetch(c)[row] }.join('.') }
    end

    def self.width(text = TEXT) = bits(text).first.length

    # Three rows of half blocks with ANSI colours, each as wide as the logo.
    def self.half_blocks(text = TEXT, colors: MODERN_COLORS)
      rows = [*bits(text), '.' * width(text)]
      rows.each_slice(2).with_index.map do |(top, bottom), i|
        "#{colors[i]}#{top.chars.zip(bottom.chars).map { |t, b| HALF_BLOCKS.fetch("#{t}#{b}") }.join}\e[0m"
      end
    end

    # Five rows of reversed spaces, one colour a row, for the C64.
    def self.reversed(colors, text = TEXT, reverse: "\e[7m", normal: "\e[27m")
      bits(text).each_with_index.map do |row, i|
        "#{colors[i]}#{row.gsub(/#+/) { |run| "#{reverse}#{' ' * run.size}#{normal}" }.tr('.', ' ')}"
      end
    end
  end
end
