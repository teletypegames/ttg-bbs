# frozen_string_literal: true

module UI
  # A photo (PixelsModel) drawn in characters, two pixels a cell, one above the other: on a modern
  # terminal as upper half blocks in two xterm-256 colours, on a Commodore 64 in its sixteen
  # colours on the black screen, where a cell has one colour: a full block, an upper or a lower
  # half, or the colour nearest both when the two halves differ.
  module Picture
    CUBE  = [0, 95, 135, 175, 215, 255].freeze
    BLACK = Rubbs::Petscii::Canvas::BLACK
    SPACE = 0x20
    # The lower half block; reversed, the upper half.
    HALF  = 0xa2
    C64   = Rubbs::Petscii::Canvas::RGB

    # The lines of +pixels+ in ANSI for a modern terminal.
    def self.modern_lines(pixels)
      (0...((pixels.height + 1) / 2)).map do |row|
        line = +''
        last = nil
        pixels.width.times do |x|
          sgr = "\e[38;5;#{xterm(pixels.at(x, row * 2))};48;5;#{xterm(pixels.at(x, (row * 2) + 1))}m"
          line << sgr unless sgr == last
          last = sgr
          line << '▀'
        end
        line << "\e[0m"
      end
    end

    # The cells of +pixels+ for a C64 screen, a row of [code, colour, reversed] each.
    def self.c64_cells(pixels)
      (0...((pixels.height + 1) / 2)).map do |row|
        pixels.width.times.map { |x| cell(c64(pixels.at(x, row * 2)), c64(pixels.at(x, (row * 2) + 1)), pixels, x, row) }
      end
    end

    def self.cell(top, bottom, pixels, x, row)
      return top == BLACK ? [SPACE, BLACK, false] : [SPACE, top, true] if top == bottom
      return [HALF, top, true] if bottom == BLACK
      return [HALF, bottom, false] if top == BLACK

      [SPACE, c64(mean(pixels.at(x, row * 2), pixels.at(x, (row * 2) + 1))), true]
    end

    def self.mean(one, two) = one.zip(two).map { |a, b| (a + b) / 2 }

    # The C64 colour nearest +rgb+, weighted the way the eye sees.
    def self.c64(rgb) = C64.min_by { |_code, c| distance(rgb, c) }.first

    # The xterm-256 index nearest +rgb+: the colour cube or the grey ramp.
    def self.xterm(rgb)
      levels = rgb.map { |v| CUBE.each_index.min_by { |i| (CUBE[i] - v).abs } }
      grey   = grey_step(rgb)
      return 232 + grey if distance(rgb, [8 + (grey * 10)] * 3) < distance(rgb, levels.map { |i| CUBE[i] })

      16 + (36 * levels[0]) + (6 * levels[1]) + levels[2]
    end

    # The step of the grey ramp (232-255) nearest +rgb+'s brightness.
    def self.grey_step(rgb) = ((rgb.sum / 3) - 8).clamp(0, 238) / 10

    def self.distance(one, two)
      r, g, b = one.zip(two).map { |a, c| a - c }
      (2 * r * r) + (4 * g * g) + (3 * b * b)
    end
  end
end
