# frozen_string_literal: true

module UI
  module Petscii
    # The C64 line of one call: raw PETSCII out (the session's encoder speaks
    # the lowercase set, the switchboard draws in the graphics set), keys in.
    class Screen
      attr_reader :session

      def initialize(session)
        @session = session
      end

      def raw(bytes) = @session.write_raw(bytes)

      # The session's idle limit in seconds, nil for none.
      def idle_limit = @session.idle_seconds

      # A key, or :idle after +timeout+ seconds; a hang-up ends the call.
      def key(timeout: nil)
        k = @session.readkey(timeout: timeout)
        raise IOError, 'the caller hung up' if k.nil?

        k
      end
    end
  end
end
