# frozen_string_literal: true

module UI
  module Modern
    # What the modern face does: the caller's desk for the post office, the two columns under it
    # (the newest letters, the newest notes of the wall), and the screens of ttg-common on the line.
    module Helpers
      # The width of a column under the post office.
      COLUMN = 36

      def mailbox = with_line { TTG::PrivateMessage.open(@session) }

      def wall = with_line { TTG::Wall.open(@session) }

      def feedback = with_line { TTG::Feedback.open(@session) }

      # The caller's DeskModel.
      def desk = mail.desk(Rubbs::Common::Central::Actor.of(@session))

      # The caller's name, nil for a guest.
      def caller_or_nil = signed_in? ? identity.name : nil

      # Row +index+ of the left column: the newest letters to the caller.
      def post_row(index)
        return '✉ YOUR POST' if index.zero?
        return post_hint(index) unless signed_in?

        letter = desk.letters[index - 1] or return (index == 1 ? '  Your box is empty.' : '')
        mark = letter[:new] ? '★' : ' '
        "#{mark} #{letter[:from]}: #{letter[:subject].empty? ? '…' : letter[:subject]}"[0, COLUMN]
      end

      # Row +index+ of the right column: the newest notes of the wall.
      def wall_row(index)
        return '▒ ON THE WALL' if index.zero?

        note = desk.notes.reverse[index - 1] or return (index == 1 ? '  Nothing on the wall yet.' : '')
        "#{note[:name]}: #{note[:text]}"[0, COLUMN]
      end

      private

      def post_hint(index) = ['', '  Log in to read your letters:', '  You › Profile (or P on a C64).'][index].to_s
    end
  end
end
