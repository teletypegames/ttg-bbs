# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # Our own servers: a row a board (its number, the block of its colour,
      # its name, a dotted leader, its port), the lit one a cyan bar, and
      # under a rule the lit board's name, description, address and tags.
      # RETURN or its digit dials it (+on_dial+); while it dials the row
      # flashes white. The boards are asked again (+boards+, a callable) on
      # every draw: a board of a role shows once the caller signs in with it.
      # A board that is not published shows GATE for its port.
      class OwnView < Picker
        PER_PAGE = 10
        HINT = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Dial', false]].freeze

        attr_writer :flash

        def initialize(boards, on_dial:)
          @source = boards.respond_to?(:call) ? boards : -> { boards }
          super(@source.call, per_page: PER_PAGE)
          @on_dial = on_dial
          @flash   = false
        end

        def section = :own

        def take(board) = @on_dial.call(board)

        def hint = pages_count > 1 ? HINT[0, 3] + [[' Dial  ', false], ['+/-', true], [' Page', false]] : HINT

        def draw(canvas)
          reload_items(@source.call)
          Layout.band(canvas, 'OWN SERVERS', page_mark, Canvas::YELLOW)
          on_page.each_with_index { |board, slot| row(canvas, Layout.row(1 + slot), board, slot) }
          info(canvas, Layout.row(1 + PER_PAGE))
        end

        def self.color(board) = UI::Colors.c64(board.rgb)

        private

        def row(canvas, row, board, slot)
          name   = Layout.plain(board.name)[0, 28]
          port   = port_of(board)
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

        # The port at the end of the row; GATE for a board only the gate reaches.
        def port_of(board) = board.local? ? 'GATE' : board.port.to_s

        def info(canvas, top)
          board = selected
          return unless board

          Layout.rule(canvas, top)
          canvas.text(top + 1, 1, Layout.plain(board.name)[0, Layout::EDGE - 1], Canvas::WHITE)
          Layout.wrap(board.summary, Layout::EDGE - 1, 2).each_with_index do |line, i|
            canvas.text(top + 2 + i, 1, line, Canvas::LIGHT_GREY)
          end
          address(canvas, top + 5, board)
        end

        # The board's host and port from +top+, and its tags when they fit.
        def address(canvas, top, board)
          down = board.local? ? local_address(canvas, top) : public_address(canvas, top, board)
          return if top + 2 + down > Layout::BOTTOM

          tags = board.tags.map { |t| Layout.plain(t) }
          Layout.runs(canvas, top + 2 + down, 1, tags.flat_map { |t| [['/', Canvas::DARK_GREY], [t, Canvas::PURPLE]] }.drop(1))
        end

        # Telnet and Port: the rows it took past the first.
        def public_address(canvas, top, board)
          canvas.text(top, 1, 'Telnet ', Canvas::GREY)
          down = Layout.address(canvas, top, 8, board.public_host, nil) - 1
          Layout.runs(canvas, top + 1 + down, 1, [['Port   ', Canvas::GREY], [board.port.to_s, Canvas::CYAN]])
          down
        end

        # A board only the gate reaches: one row more, like Telnet and Port.
        def local_address(canvas, top)
          canvas.text(top, 1, 'Only through the gate', Canvas::GREY)
          canvas.text(top + 1, 1, 'Your account opens it', Canvas::GREY)
          0
        end
      end
    end
  end
end
