# frozen_string_literal: true

module UI
  module Petscii
    BBS::Petscii::Colors.install(self)

    COLS  = BBS::Petscii::Screen::COLS
    WIDTH = BBS::Petscii::Screen::WIDTH

    # The 40×25 screen of one call (BBS::Petscii::Screen), with the board's
    # own chat line.
    class Screen < BBS::Petscii::Screen
      # A chat line: what +poll+ brings shows up above the line being typed.
      # +on_line+ gets every line sent; an empty line or ← leaves.
      def chat(prompt, poll:, on_line: nil)
        buffer = +''
        write prompt
        loop do
          k = key(timeout: 1)
          case k
          when :idle
            lines = poll.call
            next if lines.empty?

            write "\r#{' ' * (cols - 1)}\r"
            lines.each { |l| fit([l]).each { |w| puts w } }
            write "#{prompt}#{buffer}"
          when :escape then return puts
          when :enter
            return puts if buffer.strip.empty? || on_line.nil?

            puts
            on_line.call(buffer.strip)
            buffer = +''
            write prompt
          when :backspace
            next if buffer.empty?

            buffer.chop!
            write "\b \b"
          when String
            next if on_line.nil? || buffer.length >= cols - 4 - BBS::FrameBuffer.visible_width(prompt)

            buffer << k
            write k
          end
        end
      end
    end
  end
end
