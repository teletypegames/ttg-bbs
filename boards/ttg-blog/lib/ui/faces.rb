# frozen_string_literal: true

require_relative 'screen'
require_relative 'board'

module UI
  # The two faces of the board. Both run the same line-by-line Board; they
  # differ in the size of the screen and in the masthead: half blocks on a
  # modern terminal, reversed spaces on a C64.
  module Faces
    LOGO_FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'G' => %w[### #.. #.# #.# ###], 'B' => %w[##. #.# ##. #.# ##.],
      'L' => %w[#.. #.. #.. #.. ###], 'O' => %w[### #.# #.# #.# ###], ' ' => %w[. . . . .]
    }.freeze
    LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

    MOTTO = 'news from teletype games'

    # TTG BLOG as five rows of bits, # set and . clear.
    def self.bits = 5.times.map { |row| 'TTG BLOG'.chars.map { |c| LOGO_FONT[c][row] }.join('.') }

    # Two rows of bits in one row of half blocks.
    def self.modern_logo
      rows = bits << ('.' * bits.first.length)
      rows.each_slice(2).map do |top, bottom|
        top.chars.zip(bottom.chars).map { |t, b| { '##' => '█', '#.' => '▀', '.#' => '▄' }.fetch("#{t}#{b}", ' ') }.join
      end
    end

    def self.c64_logo
      bits.each_with_index.map do |row, i|
        "  #{LOGO_COLORS[i]}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
      end
    end

    def self.modern_masthead(cols)
      rule = " #{DG}#{'─' * (cols - 2)}#{LG}"
      [rule, *modern_logo.map { |l| "  #{YE}#{l}#{LG}" }, rule, "  #{WH}#{MOTTO}#{LG}"]
    end

    def self.c64_masthead
      rule = " #{DG}#{'─' * (Screen::C64_COLS - 2)}#{LG}"
      [rule, '', *c64_logo, '', rule, "  #{WH}#{MOTTO}#{LG}"]
    end

    def self.modern(blog)
      flow(blog) do |session|
        cols = session.term_cols.clamp(40, 80)
        [Screen.new(session, cols: cols, rows: session.term_rows.clamp(16, 60)), modern_masthead(cols)]
      end
    end

    def self.c64(blog)
      flow(blog) { |session| [Screen.new(session, cols: Screen::C64_COLS, rows: 25), c64_masthead] }
    end

    def self.flow(blog, &face)
      BBS::Flow.define do
        call do |ctx, runner|
          screen, masthead = face.call(runner.session)
          Board.new(blog, screen, ctx, masthead: masthead).run
          Faces.goodbye(screen)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(screen)
      screen.cls
      screen.puts
      screen.puts " #{YE}#{RV}#{' thanks for reading ttgblog'.ljust(screen.cols - 1)}#{RO}#{LG}"
      screen.puts
      screen.say('More of us: teletypegames.org', GR)
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end
  end
end
