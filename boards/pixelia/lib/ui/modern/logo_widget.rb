# frozen_string_literal: true

require_relative '../logo'
require_relative 'art_lines'

module UI
  module Modern
    # PIXELIA in half blocks on the desktop, each letter in its colour, and
    # the board's line under it.
    class LogoWidget < BBS::Widget
      HEIGHT  = 5
      TAGLINE = 'The PETSCII & ANSI art gallery'

      def render(frame)
        left = bounds.x + [(bounds.width - Logo.width) / 2, 0].max
        Logo.half_blocks.each_with_index { |runs, row| letters(frame, runs, left, bounds.y + row) }
        tagline(frame)
      end

      private

      def tagline(frame)
        frame.move(bounds.x + [(bounds.width - TAGLINE.length) / 2, 0].max, bounds.y + 4)
        frame.write(TAGLINE, sgr: style(:text_bright))
      end

      def letters(frame, runs, x, y)
        runs.each do |text, color|
          frame.move(x, y)
          frame.write(text, sgr: "\e[0;38;5;#{ColorModel[color || 0].xterm};40m")
          x += text.length
        end
      end
    end
  end
end
