# frozen_string_literal: true

module UI
  module Petscii
    class Gate < BBS::Pages
      # What the gate reads besides a view's keys: the search line on the
      # hint row, and a key over a notice.
      module Input
        private

        # The search: the input line in place of the hint bar, then its list.
        # The caller's profile (BBS::Auth::Profile, the look of TTG::PRESET)
        # on the bare line, then back.
        def account = hand_over { BBS::Auth::Profile.run(session) }

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

        # The line being read, on the hint row: the label, the words, a
        # reversed cell for the cursor.
        def input_line(canvas)
          text = line.text
          canvas.text(Layout::HINT_ROW, 0, INPUT_LABEL, Canvas::LIGHT_GREEN)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1, text, Canvas::WHITE)
          canvas.text(Layout::HINT_ROW, INPUT_LABEL.length + 1 + text.length, ' ', Canvas::WHITE, rvs: true)
        end

        # Shows +target+ (a Views::TextView) over the current view until a
        # key (or until the block answers one, see BBS::Pages#show); the
        # answer.
        def pop_up(target, hint: [['Press a key', false]], &)
          target.hint = hint
          show(target, &)
        end
      end
    end
  end
end
