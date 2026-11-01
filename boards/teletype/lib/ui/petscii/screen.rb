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
        @chat = ChatLine.new(prompt, poll, on_line)
        write prompt
        loop do
          k = key(timeout: 1)
          return puts if k == :escape || (k == :enter && !chat_sent?)

          chat_key(k)
        end
      end

      private

      # The line being typed, its prompt, and where lines come from and go.
      ChatLine = Struct.new(:prompt, :poll, :on_line) do
        def buffer = (@buffer ||= +'')
        def clear = @buffer = +''
      end

      def chat_key(k)
        case k
        when :idle      then show_chat(@chat.poll.call)
        when :backspace then chat_backspace
        when String     then chat_type(k)
        end
      end

      # Sends the line typed; false when it was empty (or there is nowhere
      # to send): the chat is over.
      def chat_sent?
        line = @chat.buffer.strip
        return false if line.empty? || @chat.on_line.nil?

        puts
        @chat.on_line.call(line)
        @chat.clear
        write @chat.prompt
        true
      end

      def show_chat(lines)
        return if lines.empty?

        write "\r#{' ' * (cols - 1)}\r"
        lines.each { |l| fit([l]).each { |w| puts w } }
        write "#{@chat.prompt}#{@chat.buffer}"
      end

      def chat_backspace
        return if @chat.buffer.empty?

        @chat.buffer.chop!
        write "\b \b"
      end

      def chat_type(char)
        return if @chat.on_line.nil? || @chat.buffer.length >= cols - 4 - BBS::FrameBuffer.visible_width(@chat.prompt)

        @chat.buffer << char
        write char
      end
    end
  end
end
