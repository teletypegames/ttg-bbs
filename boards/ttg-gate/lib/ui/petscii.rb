# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'petscii/screen'
require_relative 'petscii/switchboard'

module UI
  # TTG Gate on a Commodore 64: the Switchboard, raw PETSCII in the
  # graphics set. CRSR moves between the boards, RETURN or a digit dials,
  # + and - turn the pages, Q or RUN/STOP hangs up. While the caller thinks,
  # the stars twinkle.
  module Petscii
    # Seconds between two twinkles.
    TICK = 1.5
    # Seconds between two steps of the dialling.
    STEP = 0.12
    MOVES = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] }.freeze

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
      board = Switchboard.new(boards)
      screen.raw(board.frame)
      idle = 0.0
      loop do
        key = screen.key(timeout: TICK)
        if key == :idle
          idle += TICK
          return goodbye(screen) if screen.idle_limit && idle >= screen.idle_limit

          screen.raw(board.twinkle)
          next
        end

        idle = 0.0
        case key
        when :escape, 'q', 'Q' then return goodbye(screen)
        when *MOVES.keys then screen.raw(board.move(*MOVES[key]))
        when '+' then screen.raw(board.turn(1))
        when '-' then screen.raw(board.turn(-1))
        when :enter then dial(screen, board)
        when /\A[1-#{Switchboard::PER_PAGE}]\z/
          next unless board.board_at(key.to_i)

          screen.raw(board.select(key.to_i - 1))
          dial(screen, board)
        end
      end
    end

    # The button flashes, the dots roll, and the line goes to the board;
    # the whole switchboard again when the board hangs up.
    def self.dial(screen, board)
      target = board.selected
      return unless target

      board.dial_steps.each do |step|
        screen.raw(step)
        sleep STEP
      end
      screen.raw([Canvas::LOWERCASE, Canvas::CLEAR].pack('C*'))
      UI.dial(screen.session, target)
      screen.raw(board.frame)
    end

    def self.goodbye(screen)
      canvas = Canvas.new
      canvas.text(9, 9, '♥ ♦ ♣ ♠ ♥ ♦ ♣ ♠ ♥ ♦ ♣', Canvas::LIGHT_RED)
      canvas.text(11, 10, 'TTG GATE: LINE CLOSED', Canvas::WHITE)
      canvas.text(12, 11, 'SEE YOU ON THE WIRE', Canvas::CYAN)
      canvas.text(14, 9, '♠ ♣ ♦ ♥ ♠ ♣ ♦ ♥ ♠ ♣ ♦', Canvas::PURPLE)
      canvas.text(17, 15, 'NO CARRIER', Canvas::LIGHT_RED)
      screen.raw(canvas.frame + [Canvas::LOWERCASE].pack('C*'))
      nil
    end
  end
end
