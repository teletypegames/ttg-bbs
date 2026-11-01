# frozen_string_literal: true

module UI
  module Modern
    # The look of the modern face, shared by its screens: the palette of
    # bbsweb, a margin, a width of at most MAX_WIDTH, and the whole-screen
    # repaint (each line cleared to its end, nothing scrolls).
    module Style
      GREEN  = "\e[38;5;84m"
      TEXT   = "\e[38;5;250m"
      DIM    = "\e[38;5;244m"
      LINE   = "\e[38;5;238m"
      YELLOW = "\e[38;5;221m"
      RED    = "\e[38;5;203m"
      SELECT = "\e[48;5;235m"
      BOLD   = "\e[1m"
      RESET  = "\e[0m"

      # The colour of a board's state mark.
      STATE_COLORS = { 'online' => GREEN, 'flaky' => YELLOW, 'down' => RED, 'dead' => DIM, 'unknown' => TEXT }.freeze

      MAX_WIDTH = 100
      MARGIN    = 2

      LOGO = [
        ' _____ _____ ___    ___   _ _____ ___',
        '|_   _|_   _/ __|  / __| /_\\_   _| __|',
        '  | |   | || (_ | | (_ |/ _ \\| | | _|',
        '  |_|   |_| \\___|  \\___/_/ \\_\\_| |___|'
      ].freeze

      TABS = { own: 'OWN SERVERS', discovery: 'GLOBAL DISCOVERY' }.freeze

      def width = @session.term_cols.clamp(40, MAX_WIDTH) - MARGIN

      def rows = @session.term_rows.clamp(12, 200)

      def pad = ' ' * MARGIN

      def rule = "#{LINE}#{'─' * width}#{RESET}"

      # +text+ cut or padded to +size+ columns, an ellipsis where it was cut;
      # no control character of it reaches the caller (a second guard after
      # Discovery::Address.text, for what the catalog held before it).
      def fit(text, size)
        size = [size, 0].max
        text = plain(text)
        text.length > size ? "#{text[0, [size - 1, 0].max]}…" : text.ljust(size)
      end

      # +text+ on one line with no control or bidi character (BBS::Text.clean).
      def plain(text) = BBS::Text.clean(text, keep_newlines: false).tr("\t", ' ')

      def mark(listing) = "#{STATE_COLORS.fetch(listing.state, TEXT)}#{listing.mark}#{RESET}"

      # The logo and the two-way chooser of the gate, +tab+ lit.
      def masthead(tab)
        tabs = TABS.map do |key, label|
          key == tab ? "#{SELECT}#{GREEN}#{BOLD} #{label} #{RESET}" : "#{DIM} #{label} #{RESET}"
        end.join("#{LINE}│#{RESET}")
        right = 'TAB switches'
        room  = width - TABS.values.sum { |l| l.length + 2 } - 1 - right.length
        ['', *LOGO.map { |l| "#{GREEN}#{l}#{RESET}" }, "#{tabs}#{' ' * [room, 1].max}#{DIM}#{right}#{RESET}", rule]
      end

      # The top line of a Discovery screen: where the caller is, and +right+.
      def crumbs(path, right = '')
        right = plain(right)
        left  = fit("GLOBAL DISCOVERY › #{path}", width - right.length - 1).rstrip
        "#{GREEN}#{BOLD}#{left}#{RESET}#{' ' * [width - left.length - right.length, 1].max}#{DIM}#{right}#{RESET}"
      end

      # Repaints the screen with +lines+, at most a screenful, the cursor
      # hidden.
      def paint(lines)
        out = "\e[?25l#{RESET}\e[H"
        lines.first(rows - 1).each { |l| out << "#{pad}#{l}#{RESET}\e[K\r\n" }
        out << "\e[J"
        @session.write(out)
      end

      # A key; a hang-up ends the call (IOError).
      def key
        k = @session.readkey
        raise IOError, 'the caller hung up' if k.nil?

        k
      end

      # Clears the screen for a line of text (a dial, a banner).
      def clear = @session.write("#{RESET}\e[2J\e[H\e[?25h")

      # After a board or a banner had the screen: colours, mouse and cursor
      # back to ours.
      def restore = @session.write("#{RESET}\e[?1000l\e[?1002l\e[?1006l\e[?25h")

      def date(at) = at ? Time.at(at).strftime('%Y-%m-%d %H:%M') : 'never'
    end
  end
end
