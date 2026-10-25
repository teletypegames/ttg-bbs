# frozen_string_literal: true

module UI
  # The first question of a call: which face of the board the terminal
  # gets. The board guesses first from the telnet answers: a window wider
  # than 40 columns is a modern terminal; 40 columns, or no answer at all
  # (a C64 behind a WiFi modem talks plain TCP), most likely a Commodore.
  # The caller takes the guess with RETURN or picks the other one. The
  # question is plain ASCII in capitals, which an ANSI terminal and a C64
  # in either character set print alike.
  module Terminal
    SETTLE = 1.5
    WAIT   = 60

    def self.guess(session)
      session.settle(timeout: SETTLE) && session.term_cols > BBS::Petscii::COLS ? :modern : :c64
    end

    # :modern or :c64; nil when the line drops. A caller who does not answer
    # gets the guess.
    def self.choose(session)
      guess   = guess(session)
      default = guess == :modern ? '1' : '2'
      session.write "\r\n\r\nTELETYPE BBS\r\n\r\n" \
                    "1 - ANSI TERMINAL (PC, MAC, WEB)\r\n" \
                    "2 - COMMODORE 64 (PETSCII)\r\n\r\n" \
                    "YOUR TERMINAL [#{default}]: "
      loop do
        choice = case session.readkey(timeout: WAIT)
                 when nil                  then return nil
                 when :enter, :idle        then default
                 when '1', 'a', 'A'        then '1'
                 when '2', 'c', 'C'        then '2'
                 end
        next unless choice

        session.write "#{choice}\r\n"
        return choice == '1' ? :modern : :c64
      end
    end
  end
end
