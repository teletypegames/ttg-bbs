# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'petscii/screen'

module UI
  # TTG Gate on a Commodore 64: the logo in reversed blocks and the boards
  # with a C64 face, numbered in their own colours. The number dials, Q or
  # RUN/STOP hangs up.
  module Petscii
    LETTERS = {
      'T' => %w[### .#. .#. .#. .#.],
      'G' => %w[.## #.. #.# #.# .##],
      'A' => %w[.#. #.# ### #.# #.#],
      'E' => %w[### #.. ##. #.. ###],
      ' ' => %w[. . . . .]
    }.freeze

    # TTG GATE in rows of bits, # a reversed space.
    LOGO_BITS = Array.new(5) { |r| 'TTG GATE'.chars.map { |c| LETTERS.fetch(c)[r] }.join('.') }.freeze

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Petscii.menu(Screen.new(runner.session), bbs.directory.boards(petscii: true))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.menu(screen, boards)
      loop do
        draw(screen, boards)
        key = screen.key
        return goodbye(screen) if [:escape, 'q', 'Q'].include?(key)

        board = key.is_a?(String) && key.match?(/\A[1-9]\z/) ? boards[key.to_i - 1] : nil
        next unless board

        screen.puts(key)
        UI.dial(screen.session, board)
      end
    end

    def self.logo
      LOGO_BITS.map do |row|
        "     #{GN}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
      end
    end

    def self.draw(screen, boards)
      screen.cls
      screen.puts
      logo.each { |l| screen.puts l }
      screen.puts
      screen.puts "  #{GR}choose a system to dial#{LG}"
      screen.puts " #{DG}#{'─' * (COLS - 2)}#{LG}"
      boards.each_with_index do |board, i|
        screen.puts " #{YE}#{i + 1}#{LG} #{Colors.petscii(board.rgb)}#{board.name}#{LG}"
        screen.puts "   #{GR}#{BBS::FrameBuffer.clip_ansi(board.tags.join(', '), COLS - 4)}#{LG}"
      end
      screen.puts
      screen.write " #{GR}number: dial  q: hang up#{LG}\r\n #{WH}>#{LG} "
    end

    def self.goodbye(screen)
      screen.puts
      screen.puts
      screen.puts " #{GN}TTG GATE#{GR}: line closed. See you.#{LG}"
      nil
    end
  end
end
