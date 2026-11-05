# frozen_string_literal: true

module UI
  module Modern
    # The line a screen of the modern face reads at its bottom: its hint
    # above it, the label, the words, the cursor after them.
    module Prompt
      include Style

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
