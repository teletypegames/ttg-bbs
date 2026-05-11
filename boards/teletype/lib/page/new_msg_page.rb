# frozen_string_literal: true

module NewMsgPage
  def self.configure(tui)
    tui.page :new_msg do
      enter { @page_title = 'POST MESSAGE'; @input = +''; @status = +'' }

      render do
        text 'Type your message and press Enter.  Esc cancels.',
             x: CONT_X, y: CONT_Y, style: THEME[:normal]
        text "#{tc(:bright, @username)}: #{tc(:input, @input)}_",
             x: CONT_X, y: CONT_Y + 2
        unless @status.empty?
          text @status, x: CONT_X, y: CONT_Y + 4, style: THEME[:error]
        end
      end

      key(:enter) do
        if @input.strip.empty?
          @status = 'Message cannot be empty.'
        else
          MESSAGES.append(@username, @input.strip[0...200])
          go :idle
        end
      end
      key(:backspace) { @input.chop! unless @input.empty? }
      key(:escape)    { go :idle }
      printable       { |ch| @input << ch if @input.length < 200 }
    end
  end
end
