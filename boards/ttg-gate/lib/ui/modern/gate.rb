# frozen_string_literal: true

module UI
  module Modern
    # The pages of the modern face: the two sides of the chooser (our own
    # boards and Global Discovery), each keeping its place while the other
    # is shown, and the search line at the bottom of the screen while it is
    # read.
    class Gate < BBS::Pages
      include Style

      def initialize(session, bbs)
        super(session, face: :modern)
        @sides = {
          own:       OwnServers.new(bbs.directory.boards, accounts: bbs.accounts),
          discovery: Discovery::Home.new(Discovery::Context.new(session: session, browse: bbs.browse, dials: bbs.dials))
        }
        @side = :own
      end

      # Runs the chooser from our own boards (or on from where it was) until
      # the caller hangs up.
      def run(page = (@sides[:own] if stack.empty?)) = super

      # Turns to the other side of the chooser.
      def switch
        @side = @side == :own ? :discovery : :own
        reset(@sides[@side])
      end

      def draw(frame)
        super
        prompt(frame) if line
      end

      private

      # The search line: its hint above it, the label, the words, the
      # cursor after them.
      def prompt(frame)
        label = line.label.to_s
        shown = line.tail(width - label.length - 3)
        print_lines(
          frame,
          [hint_line, "#{GREEN}#{BOLD}#{label}#{RESET} #{TEXT}#{shown}#{RESET}"],
          x:     MARGIN + 1,
          y:     rows - 2,
          clear: true
        )
        cursor(rows - 1, MARGIN + label.length + shown.length + 2)
      end

      def hint_line = "#{DIM}#{fit(line.hint.to_s, width)}#{RESET}"
    end
  end
end
