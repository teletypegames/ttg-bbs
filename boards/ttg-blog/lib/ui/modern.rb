# frozen_string_literal: true

require_relative 'board'

module UI
  # The blog on a modern terminal (ANSI colours, UTF-8): the line-by-line
  # Board on the caller's window, up to 80 columns, under a masthead in half
  # blocks.
  module Modern
    # Two rows of bits in one row of half blocks.
    def self.logo
      rows = Board.logo_bits << ('.' * Board.logo_bits.first.length)
      rows.each_slice(2).map do |top, bottom|
        top.chars.zip(bottom.chars).map { |t, b| { '##' => '█', '#.' => '▀', '.#' => '▄' }.fetch("#{t}#{b}", ' ') }.join
      end
    end

    def self.masthead(cols)
      rule = " #{DG}#{'─' * (cols - 2)}#{LG}"
      [rule, *logo.map { |l| "  #{YE}#{l}#{LG}" }, rule, "  #{WH}#{Board::MOTTO}#{LG}"]
    end

    def self.flow(blog)
      Board.flow(blog) do |session|
        cols = session.term_cols.clamp(40, 80)
        [Screen.new(session, cols: cols, rows: session.term_rows.clamp(16, 60)), masthead(cols)]
      end
    end
  end
end
