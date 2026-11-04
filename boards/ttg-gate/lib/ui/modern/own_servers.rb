# frozen_string_literal: true

module UI
  module Modern
    # The dialing menu of our own boards on an ANSI terminal, after the list
    # of bbsweb: the logo and the chooser, one row a board with its colour
    # bar, and under the list the chosen board's description. The arrows
    # choose, RETURN or the board's number dials, TAB turns to Global
    # Discovery, P opens the caller's profile (their account), Q or Esc
    # hangs up.
    class OwnServers < Screen
      NAME = 18

      key(:up)   { @index = (@index - 1) % @boards.size }
      key(:down) { @index = (@index + 1) % @boards.size }
      key(:enter) { dial(@boards[@index]) }
      key(:tab, :right, :left, 'g', 'G') { pages.switch }
      key(:escape, 'q', 'Q') { quit }
      key('p', 'P', 'a', 'A') { hand_over { UI::Account.run(session, @accounts) } if @accounts }
      key(/\A[1-9]\z/) do |k|
        board = @boards[k.to_i - 1]
        next unless board

        @index = k.to_i - 1
        dial(board)
      end

      def initialize(boards, accounts: nil)
        super()
        @boards   = boards
        @accounts = accounts
        @index = 0
      end

      def lines
        lines = [*masthead(:own), '']
        lines.concat(@boards.each_with_index.map { |b, i| row(b, i) })
        room = rows - 1 - lines.size - 5
        lines.push('', rule, *detail(@boards[@index], room.clamp(0, 4)), '', hints)
      end

      private

      def dial(board) = hand_over { UI.dial(session, board) }

      # One board: its colour bar, number, name, tags and address; the
      # chosen one on a lit background with DIAL at its end.
      def row(board, index)
        color   = Colors.ansi256(board.rgb)
        lit     = index == @index ? SELECTED : ''
        address = "  #{width >= 90 ? board.address : board.port}"
        "#{color}▌#{RESET}#{lit} #{DIM}#{index + 1}  #{color}#{BOLD}#{fit(board.name, NAME)}#{RESET}#{lit}  " \
          "#{DIM}#{fit(board.tags.join(' · '), tags_width(address))}#{address}  " \
          "#{color}#{(lit.empty? ? '' : 'DIAL >').ljust(6)} #{RESET}"
      end

      # The columns left for a row's tags beside its +address+.
      def tags_width(address) = width - (1 + 1 + 1 + 2 + NAME + 2) - address.length - (2 + 6 + 1)

      def detail(board, lines)
        color = Colors.ansi256(board.rgb)
        body  = BBS::FrameBuffer.wrap_ansi(board.summary, width).first(lines)
        ["#{color}#{BOLD}#{board.name}#{RESET}  #{DIM}#{board.address}#{RESET}", *body.map { |l| "#{TEXT}#{l}#{RESET}" }]
      end

      def hints = "#{DIM}↑↓ choose   RETURN or 1-#{@boards.size} dial   TAB Global Discovery   P profile   Q hang up#{RESET}"
    end
  end
end
