# frozen_string_literal: true

module UI
  module Modern
    # The look of the modern face, shared by its screens: the palette of
    # bbsweb, a margin and a width of at most MAX_WIDTH. A screen is a
    # BBS::Page of lines (Screen).
    module Style
      GREEN  = BBS::Style[fg: 84]
      TEXT   = BBS::Style[fg: 250]
      DIM    = BBS::Style[fg: 244]
      LINE   = BBS::Style[fg: 238]
      YELLOW = BBS::Style[fg: 221]
      RED    = BBS::Style[fg: 203]
      SELECTED = BBS::Style[bg: 235]
      BOLD   = BBS::Style[bold: true]
      RESET  = BBS::Style::RESET

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

      def width = session.term_cols.clamp(40, MAX_WIDTH) - MARGIN

      def rows = session.term_rows.clamp(12, 200)

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

      # A row of a menu: +label+ in +size+ columns and +note+, lit with an
      # arrow when chosen.
      def menu_row(label, note, size, lit:)
        "#{lit ? "#{SELECTED}#{GREEN}▸ " : '  '}#{BOLD}#{fit(label, size)}#{RESET}" \
          "#{SELECTED if lit}#{DIM}#{fit(note, width - size - 2)}#{RESET}"
      end

      def mark(listing) = "#{STATE_COLORS.fetch(listing.state, TEXT)}#{listing.mark}#{RESET}"

      # The logo and the two-way chooser of the gate, +tab+ lit.
      def masthead(tab)
        tabs = TABS.map do |key, label|
          key == tab ? "#{SELECTED}#{GREEN}#{BOLD} #{label} #{RESET}" : "#{DIM} #{label} #{RESET}"
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

      def date(at) = at ? Time.at(at).strftime('%Y-%m-%d %H:%M') : 'never'
    end

    # A screen of the modern face: its #lines from the top, after the
    # margin, at most a screenful (the last row stays free).
    class Screen < BBS::Page
      include Style

      def draw(frame) = print_lines(frame, lines, x: MARGIN + 1, limit: rows - 1)

      def lines = []
    end

    # A screen of given lines: a question, a notice, until a key (#show).
    class Lines < Screen
      attr_reader :lines

      def initialize(lines)
        super()
        @lines = lines
      end
    end
  end
end
