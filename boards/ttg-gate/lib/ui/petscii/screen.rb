# frozen_string_literal: true

module UI
  module Petscii
    # Colours as ANSI, which the PETSCII line turns into the C64's own; the
    # width helpers of rubbs know ANSI and would count PETSCII codes as text.
    WH = "\e[1;37m"
    YE = "\e[1;33m"
    LG = "\e[0;37m"
    GR = "\e[2;37m"
    DG = "\e[1;30m"
    GN = "\e[1;32m"
    RV = "\e[7m"
    RO = "\e[27m"

    COLS = 40

    # The 40×25 screen of one call: the session, switched with petscii!,
    # makes PETSCII of what it writes.
    class Screen
      attr_reader :session

      def initialize(session)
        @session = session
      end

      def write(text) = @session.write(text)

      def puts(text = '')
        write("#{text}\r\n")
      end

      def cls = write("\e[0m\e[2J")

      # A key; a hang-up ends the call.
      def key
        k = @session.readkey
        raise IOError, 'the caller hung up' if k.nil?

        k
      end
    end
  end
end
