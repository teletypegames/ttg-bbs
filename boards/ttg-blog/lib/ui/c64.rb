# frozen_string_literal: true

require_relative 'board'

module UI
  # The blog on a Commodore 64: the line-by-line Board in PETSCII on a 40×25
  # screen, under a masthead in reversed spaces.
  module C64
    COLS = 40
    ROWS = 25

    LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

    def self.logo
      Board.logo_bits.each_with_index.map do |row, i|
        "  #{LOGO_COLORS[i]}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
      end
    end

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule, "  #{WH}#{Board::MOTTO}#{LG}"]
    end

    def self.flow(blog)
      Board.flow(blog) { |session| [Screen.new(session, cols: COLS, rows: ROWS), masthead] }
    end
  end
end
