# frozen_string_literal: true

require_relative 'colors'
require_relative 'dial'
require_relative 'petscii/screen'
require_relative 'petscii/switchboard'
require_relative 'petscii/discovery'

module UI
  # TTG Gate BBS on a Commodore 64: the Switchboard, raw PETSCII in the
  # graphics set. CRSR up and down move between the nodes, left and right or
  # + and - turn the pages, RETURN or a digit dials, G turns to Global
  # Discovery (UI::Petscii::Discovery) and back, Q or RUN/STOP hangs up.
  # While the caller thinks, the code rain falls.
  module Petscii
    # Seconds between two rows of rain.
    TICK = 0.5
    # Seconds between two steps of the dialling.
    STEP = 0.12
    MOVES = { up: -1, down: 1 }.freeze
    PAGES = { left: -1, right: 1, '-' => -1, '+' => 1 }.freeze

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          screen = Screen.new(runner.session)
          Petscii.menu(screen, bbs.directory.boards(petscii: true), Discovery.new(screen, bbs.browse, bbs.dials))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.menu(screen, boards, discovery = nil)
      board = Switchboard.new(boards)
      screen.raw(board.frame)
      idle = 0.0
      loop do
        key = screen.key(timeout: TICK)
        if key == :idle
          idle += TICK
          return goodbye(screen) if screen.idle_limit && idle >= screen.idle_limit

          screen.raw(board.rain)
          next
        end

        idle = 0.0
        case key
        when :escape, 'q', 'Q' then return goodbye(screen)
        when *MOVES.keys then screen.raw(board.move(MOVES[key]))
        when *PAGES.keys then screen.raw(board.turn(PAGES[key]))
        when :enter then dial(screen, board)
        when 'g', 'G'
          next unless discovery

          discovery.run
          screen.raw(board.frame)
        when /\A[1-#{Switchboard::PER_PAGE}]\z/
          next unless board.board_at(key.to_i)

          screen.raw(board.select(key.to_i - 1))
          dial(screen, board)
        end
      end
    end

    # The node flashes, the link bar fills, and the line goes to the board;
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
      canvas.text(9, 10, '> LINK SEVERED', Canvas::GREEN)
      canvas.text(10, 10, '> TRACE WIPED', Canvas::GREEN)
      canvas.text(11, 10, '> TTG GATE BBS OFFLINE', Canvas::GREEN)
      canvas.text(13, 10, 'SEE YOU ON THE WIRE', Canvas::DARK_GREY)
      canvas.text(16, 15, 'NO CARRIER', Canvas::LIGHT_GREEN)
      screen.raw(canvas.frame + [Canvas::LOWERCASE].pack('C*'))
      nil
    end
  end
end
