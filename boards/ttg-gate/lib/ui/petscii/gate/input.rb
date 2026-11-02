# frozen_string_literal: true

module UI
  module Petscii
    class Gate
      # What the gate reads besides a view's keys: the search line on the
      # hint row, a key over a notice, and the wait for a key that counts the
      # caller's idle time.
      module Input
        private

        # The search: the input line in place of the hint bar, then its list.
        def search
          text = input
          return paint if text.nil? || text.empty?

          @section = :search
          @tab = :discover
          @stack = [list("FIND #{text}", :search) { |state| @browse.search(text, petscii: true, state: state) }]
          paint(whole: true)
        end

        # Reads a line on the hint row: letters, digits and signs, DEL takes
        # one back, RETURN takes it, RUN/STOP gives up (nil).
        def input
          unless @browse
            show(resting)
            return nil
          end

          @input = +''
          paint
          loop do
            case (key = wait)
            when :enter then return @input.strip.downcase
            when :escape then return nil
            when :backspace then @input.chop!
            when String then @input << key if BBS::Text.printable?(key) && @input.length < INPUT_MAX
            end
            paint
          end
        ensure
          @input = nil
        end

        # A key, the idle time of the session counted: past it the call ends.
        def wait
          idle = 0.0
          loop do
            key = @screen.key(timeout: TICK)
            return key unless key == :idle

            idle += TICK
            raise IOError, 'idle' if @screen.idle_limit && idle >= @screen.idle_limit

            tick
          end
        end

        # Shows +target+ (a Views::TextView) over the current view until a
        # key; the key.
        def show(target, hint: [['Press a key', false]])
          target.hint = hint
          @stack.push(target)
          paint
          key = wait
          @stack.pop
          paint
          key
        end
      end
    end
  end
end
