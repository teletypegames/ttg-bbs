# frozen_string_literal: true

module UI
  module Modern
    # The dialing menu of our own boards on an ANSI terminal, after the list
    # of bbsweb: the logo and the chooser, one row a board with its colour
    # bar, and under the list the chosen board's description. The arrows
    # choose, RETURN or the board's number dials, TAB turns to Global
    # Discovery, Q or Esc hangs up.
    class Selector
      include Style

      NAME = 18

      def initialize(session, boards)
        @session = session
        @boards  = boards
        @index   = 0
      end

      # Runs the menu until the caller hangs up (nil) or turns to the other
      # side of the chooser (:switch). Raises IOError when the line drops.
      def run
        loop do
          draw
          case (k = key)
          when :up    then @index = (@index - 1) % @boards.size
          when :down  then @index = (@index + 1) % @boards.size
          when :enter then dial(@boards[@index])
          when :tab, :right, :left, 'g', 'G' then return :switch
          when :escape, 'q', 'Q' then return goodbye
          when /\A[1-9]\z/
            board = @boards[k.to_i - 1]
            next unless board

            @index = k.to_i - 1
            dial(board)
          end
        end
      end

      private

      def dial(board)
        clear
        UI.dial(@session, board)
        restore
      end

      def goodbye
        @session.write("#{RESET}\e[2J\e[H\r\n#{pad}#{GREEN}TTG GATE BBS#{RESET}#{DIM}: line closed. See you.#{RESET}\r\n\r\n")
        nil
      end

      def draw
        lines = [*masthead(:own), '']
        lines.concat(@boards.each_with_index.map { |b, i| row(b, i) })
        room = rows - 1 - lines.size - 5
        lines.push('', rule, *detail(@boards[@index], room.clamp(0, 4)), '', hints)
        paint(lines)
      end

      # One board: its colour bar, number, name, tags and address; the
      # chosen one on a lit background with DIAL at its end.
      def row(board, index)
        color   = Colors.ansi256(board.rgb)
        lit     = index == @index ? SELECT : ''
        address = "  #{width >= 90 ? board.address : board.port}"
        tags    = width - (1 + 1 + 1 + 2 + NAME + 2) - address.length - (2 + 6 + 1)
        cells = [
          "#{color}▌#{RESET}#{lit} #{DIM}#{index + 1}  ",
          "#{color}#{BOLD}#{fit(board.name, NAME)}#{RESET}#{lit}  ",
          "#{DIM}#{fit(board.tags.join(' · '), tags)}#{address}  ",
          "#{color}#{(lit.empty? ? '' : 'DIAL >').ljust(6)} "
        ]
        "#{cells.join}#{RESET}"
      end

      def detail(board, lines)
        color = Colors.ansi256(board.rgb)
        body  = BBS::FrameBuffer.wrap_ansi(board.summary, width).first(lines)
        ["#{color}#{BOLD}#{board.name}#{RESET}  #{DIM}#{board.address}#{RESET}", *body.map { |l| "#{TEXT}#{l}#{RESET}" }]
      end

      def hints = "#{DIM}↑↓ choose   RETURN or 1-#{@boards.size} dial   TAB Global Discovery   Q hang up#{RESET}"
    end
  end
end
