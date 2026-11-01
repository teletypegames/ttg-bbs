# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # Our own servers: a row a board (its number, the block of its colour,
      # its name, a dotted leader, its port), the lit one a cyan bar, and
      # under a rule the lit board's name, description, address and tags.
      # RETURN or its digit dials it (+on_dial+); while it dials the row
      # flashes white.
      class OwnView < Picker
        PER_PAGE = 10
        HINT = [['CRSR', true], [' MOVE  ', false], ['RETURN', true], [' DIAL  ', false], ['D', true],
                [' DISCOVER', false]].freeze

        attr_writer :flash

        def initialize(boards, on_dial:)
          super(boards, per_page: PER_PAGE)
          @on_dial = on_dial
          @flash   = false
        end

        def section = :own

        def take(board) = -> { @on_dial.call(board) }

        def hint = pages > 1 ? HINT[0, 4] + [['+/-', true], [' PAGE', false]] : HINT

        def draw(canvas)
          right = pages > 1 ? "#{@items.size}  #{page_mark}" : "#{@items.size} BOARDS"
          Layout.band(canvas, 'OWN SERVERS', right, Canvas::YELLOW)
          on_page.each_with_index { |board, slot| row(canvas, Layout.row(2 + slot), board, slot) }
          info(canvas, Layout.row(3 + PER_PAGE))
        end

        def self.color(board) = UI::Colors.c64(board.rgb)

        private

        def row(canvas, row, board, slot)
          name   = Layout.plain(board.name)[0, 16]
          port   = board.port.to_s
          number = format('%02d', ((@page * PER_PAGE) + slot + 1) % 100)
          leader = " #{'.' * [Layout::WIDTH - 6 - name.length - port.length - 2, 0].max} "
          if slot == @index
            bar = @flash ? Canvas::WHITE : Canvas::CYAN
            canvas.text(row, 0, "#{number}   #{name}#{leader}#{port}".ljust(Layout::WIDTH), bar, rvs: true)
            canvas.text(row, 3, ' ', nil)
          else
            Layout.runs(canvas, row, 0, [[number, Canvas::YELLOW], [' ', nil], ['█', OwnView.color(board)], [' ', nil],
                                         [name, Canvas::WHITE], [leader, Canvas::DARK_GREY], [port, Canvas::CYAN]])
          end
        end

        def info(canvas, top)
          board = selected
          return unless board

          Layout.rule(canvas, top)
          canvas.text(top + 1, 1, Layout.plain(board.name)[0, 28], Canvas::WHITE)
          Layout.wrap(board.summary, 28, 2).each_with_index do |line, i|
            canvas.text(top + 2 + i, 1, line, Canvas::LIGHT_GREY)
          end
          Layout.runs(canvas, top + 5, 1, [['TELNET ', Canvas::GREY], [Layout.plain(board.public_host), Canvas::CYAN]])
          Layout.runs(canvas, top + 6, 1, [['PORT   ', Canvas::GREY], [board.port.to_s, Canvas::CYAN]])
          tags = board.tags.map { |t| Layout.plain(t) }
          Layout.runs(canvas, top + 7, 1, tags.flat_map { |t| [['/', Canvas::DARK_GREY], [t, Canvas::PURPLE]] }.drop(1))
        end
      end
    end
  end
end
