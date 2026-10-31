# frozen_string_literal: true

module UI
  # A board's accent, #rrggbb, on either face: the nearest of xterm's 256
  # colours on a modern terminal, and on a C64 the nearest of the ANSI
  # colours the PETSCII line of rubbs turns into its own.
  module Colors
    PETSCII = {
      "\e[1;31m" => [255, 119, 119], "\e[0;31m" => [136, 0, 0],
      "\e[1;32m" => [170, 255, 102], "\e[0;32m" => [0, 204, 85],
      "\e[1;33m" => [238, 238, 119], "\e[0;33m" => [221, 136, 85],
      "\e[1;34m" => [0, 136, 255],   "\e[1;35m" => [204, 68, 204],
      "\e[1;36m" => [170, 255, 238], "\e[1;37m" => [255, 255, 255]
    }.freeze

    CUBE = [0, 95, 135, 175, 215, 255].freeze

    def self.ansi256(rgb)
      r, g, b = rgb.map { |v| CUBE.each_index.min_by { |i| (CUBE[i] - v).abs } }
      "\e[38;5;#{16 + (36 * r) + (6 * g) + b}m"
    end

    # The colours of the C64 (Pepto's palette) a board's button can take:
    # bright enough for the black letters of a reversed band.
    C64 = {
      0x05 => [255, 255, 255], 0x9f => [170, 255, 238], 0x99 => [170, 255, 102], 0x9e => [238, 238, 119],
      0x81 => [221, 136, 85],  0x96 => [255, 119, 119], 0x9c => [204, 68, 204],  0x9a => [0, 136, 255],
      0x1e => [0, 204, 85],    0x1c => [136, 0, 0]
    }.freeze

    # The PETSCII colour code of the C64 colour nearest to +rgb+.
    def self.c64(rgb) = C64.min_by { |_, c| c.zip(rgb).sum { |a, b| (a - b)**2 } }.first

    def self.petscii(rgb)
      PETSCII.min_by { |_, c| c.zip(rgb).sum { |a, b| (a - b)**2 } }.first
    end
  end
end
