# frozen_string_literal: true

module UI
  module Petscii
    class Gate < Rubbs::Petscii::Kit::Frame
      # What the gate reads besides a view's keys: the search line on the
      # hint row, and a key over a notice.
      module Input
        private

        # The search: the input line in place of the hint bar, then its list.
        # The caller's profile (Rubbs::Common::Auth::Profile, the look of TTG::PRESET)
        # on the bare line, then back.
        def account = hand_over { Rubbs::Common::Auth::Profile.run(session) }

        def search
          text = input
          return if text.nil? || text.empty?

          @section = :search
          @tab = :discover
          reset(list("FIND #{text}", :search) { |state| @browse.search(text, petscii: true, state: state) })
        end

        # Reads a line on the hint row: letters, digits and signs, DEL takes
        # one back, RETURN takes it, RUN/STOP gives up (nil).
        def input
          return pop_up(resting) && nil unless @browse

          read_line(INPUT_LABEL, max: INPUT_MAX)&.strip&.downcase
        end
      end
    end
  end
end
