# frozen_string_literal: true

module UI
  module Modern
    # The dialing menu on an ANSI terminal, after the list of bbsweb: the
    # logo, one row a board with its colour bar, and under the list the
    # chosen board's description. The arrows choose, RETURN or the board's
    # number dials, Q or Esc hangs up.
    class Selector
      LOGO = [
        ' _____ _____ ___    ___   _ _____ ___',
        '|_   _|_   _/ __|  / __| /_\\_   _| __|',
        '  | |   | || (_ | | (_ |/ _ \\| | | _|',
        '  |_|   |_| \\___|  \\___/_/ \\_\\_| |___|'
      ].freeze

      GREEN  = "\e[38;5;84m"
      TEXT   = "\e[38;5;250m"
      DIM    = "\e[38;5;244m"
      LINE   = "\e[38;5;238m"
      SELECT = "\e[48;5;235m"
      BOLD   = "\e[1m"
      RESET  = "\e[0m"

      MAX_WIDTH = 100
      MARGIN    = 2
      NAME      = 18

      def initialize(session, boards)
        @session = session
        @boards  = boards
        @index   = 0
      end

      # Runs the menu until the caller hangs up with Q or Esc. Raises
      # IOError when the line drops.
      def run
        loop do
          draw
          key = @session.readkey
          raise IOError, 'the caller hung up' if key.nil?

          case key
          when :up    then @index = (@index - 1) % @boards.size
          when :down  then @index = (@index + 1) % @boards.size
          when :enter then dial(@boards[@index])
          when :escape, 'q', 'Q' then return goodbye
          when /\A[1-9]\z/
            board = @boards[key.to_i - 1]
            next unless board

            @index = key.to_i - 1
            dial(board)
          end
        end
      end

      private

      def width = @session.term_cols.clamp(40, MAX_WIDTH) - MARGIN

      def pad = ' ' * MARGIN

      def dial(board)
        @session.write("#{RESET}\e[2J\e[H\e[?25h")
        UI.dial(@session, board)
        @session.write("#{RESET}\e[?1000l\e[?1002l\e[?1006l\e[?25h")
      end

      def goodbye
        @session.write("#{RESET}\e[2J\e[H\r\n#{pad}#{GREEN}TTG GATE#{RESET}#{DIM}: line closed. See you.#{RESET}\r\n\r\n")
        nil
      end

      def draw
        lines = ['', *LOGO.map { |l| "#{GREEN}#{l}#{RESET}" }, header, rule, '']
        lines.concat(@boards.each_with_index.map { |b, i| row(b, i) })
        lines.push('', rule, *detail(@boards[@index]), '', hints)
        out = "\e[?25l#{RESET}\e[H"
        lines.first(@session.term_rows - 1).each { |l| out << "#{pad}#{l}#{RESET}\e[K\r\n" }
        out << "\e[J"
        @session.write(out)
      end

      def header
        left  = 'CHOOSE A SYSTEM TO DIAL'
        right = 'teletypegames.org'
        "#{DIM}#{left}#{' ' * [width - left.length - right.length, 1].max}#{right}#{RESET}"
      end

      def rule = "#{LINE}#{'─' * width}#{RESET}"

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

      def detail(board)
        color = Colors.ansi256(board.rgb)
        body  = BBS::FrameBuffer.wrap_ansi(board.summary, width).first(4)
        ["#{color}#{BOLD}#{board.name}#{RESET}  #{DIM}#{board.address}#{RESET}", *body.map { |l| "#{TEXT}#{l}#{RESET}" }]
      end

      def hints = "#{DIM}↑↓ choose   RETURN or 1-#{@boards.size} dial   Q hang up#{RESET}"

      def fit(text, size)
        size = [size, 0].max
        text.length > size ? "#{text[0, [size - 1, 0].max]}…" : text.ljust(size)
      end
    end
  end
end
