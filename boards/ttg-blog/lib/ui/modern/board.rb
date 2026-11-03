# frozen_string_literal: true

module UI
  module Modern
    # The Board on a modern terminal: the caller's window, up to 80 columns,
    # under a masthead in half blocks.
    class Board < UI::Board
      FACE = 'modern'

      def self.screen(session)
        Screen.new(session, cols: session.term_cols.clamp(40, 80), rows: session.term_rows.clamp(16, 60))
      end

      # The logo in half blocks.
      def self.logo = BBS::BlockFont.half_blocks(LOGO)

      private

      # Half blocks in the screen less its title bar and the prompt under
      # the code.
      def qr_code(url, quiet:) = BBS::QR.ansi(url, width: @screen.cols - 1, height: @screen.rows - 4, quiet: quiet)

      def masthead
        rule = " #{DG}#{'─' * (@screen.cols - 2)}#{LG}"
        [rule, *Board.logo.map { |l| "  #{YE}#{l}#{LG}" }, rule, "  #{WH}#{MOTTO}#{LG}"]
      end
    end
  end
end
