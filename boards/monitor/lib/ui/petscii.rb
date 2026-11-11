# frozen_string_literal: true

module UI
  # The board on a Commodore 64: the runs of a line (UI::Paint) drawn on a
  # 40×25 PETSCII canvas in the lowercase set, each RGB colour the nearest
  # of the C64's (not black), the chosen row reversed. The pages are the
  # same on both faces; UI::Monitor runs them.
  module Petscii
    # The roles on a C64.
    PETSCII = {
      text:   :light_grey,
      dim:    :grey,
      line:   :dark_grey,
      accent: :orange,
      bright: :white,
      good:   :light_green,
      warn:   :yellow,
      bad:    :light_red
    }.freeze
    # The C64 colours an RGB colour may become (black would not show).
    C64_RGB = Rubbs::Petscii::Canvas::RGB.except(Rubbs::Petscii::Canvas::BLACK, Rubbs::Petscii::Canvas::BLUE).freeze

    module_function

    # The C64 colour code of +color+ (a role or an RGB triple).
    def c64(color)
      return Rubbs::Petscii::Canvas.color(PETSCII.fetch(color, :light_grey)) unless color.is_a?(Array)

      C64_RGB.min_by { |_, c| c.zip(color).sum { |a, b| (a - b)**2 } }.first
    end

    # Draws +line+ on +canvas+ at +row+ from column +col+, no further
    # than +width+ columns.
    def canvas(canvas, row, line, col: 0, width: Rubbs::Petscii::Canvas::COLS)
      at = col
      line.each do |text, color, lit|
        room = col + width - at
        break if room <= 0

        shown = Rubbs::Petscii::Canvas.plain(text.to_s[0, room], :lower)
        canvas.text(row, at, shown, c64(color), rvs: lit == :lit)
        at += shown.length
      end
    end
  end
end
