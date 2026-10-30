# frozen_string_literal: true

module UI
  module Petscii
    # The Board on a Commodore 64: PETSCII on a 40×25 screen, under a
    # masthead in reversed spaces.
    class Board < UI::Board
      FACE = 'petscii'

      LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

      def self.screen(session) = Screen.new(session, cols: COLS, rows: ROWS)

      def self.logo
        logo_bits.each_with_index.map do |row, i|
          "  #{LOGO_COLORS[i]}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
        end
      end

      private

      def masthead
        rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
        [rule, '', *Board.logo, '', rule, "  #{WH}#{MOTTO}#{LG}"]
      end
    end
  end
end
