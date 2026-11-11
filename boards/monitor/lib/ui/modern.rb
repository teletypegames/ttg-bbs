# frozen_string_literal: true

module UI
  # The board on a modern terminal: the runs of a line (UI::Paint) written
  # as ANSI, each role or RGB colour the nearest of xterm's 256, the chosen
  # row on a dark background. The pages (UI::Home and after) are the same
  # on both faces; UI::Monitor runs them.
  module Modern
    # The roles on a modern terminal, xterm-256 colours.
    MODERN = { text: 250, dim: 244, line: 238, accent: 208, bright: 255, good: 114, warn: 221, bad: 203 }.freeze
    # The background of the chosen row on a modern terminal.
    LIT_BG = 237
    # The steps of xterm's colour cube.
    CUBE = [0, 95, 135, 175, 215, 255].freeze

    module_function

    # The xterm-256 index of +color+ (a role or an RGB triple).
    def xterm(color)
      return MODERN.fetch(color, MODERN[:text]) unless color.is_a?(Array)

      r, g, b = color.map { |v| CUBE.each_index.min_by { |i| (CUBE[i] - v).abs } }
      16 + (36 * r) + (6 * g) + b
    end

    # +line+ (runs) as one ANSI String.
    def ansi(line)
      runs = line.map do |text, color, lit|
        bold = %i[bright accent].include?(color) ? '1;' : ''
        bg = lit ? ";48;5;#{LIT_BG}" : ''
        "\e[0m\e[#{bold}38;5;#{xterm(color)}#{bg}m#{text}"
      end
      "#{runs.join}\e[0m"
    end
  end
end
