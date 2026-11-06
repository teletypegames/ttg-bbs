# frozen_string_literal: true

module UI
  class Petscii
    private

    # ── the wall and the letters to the sysop ──────────────────────────

    # The cork board: the board's wall on the network (ttg-common TTG::Wall,
    # in the words of lib/content/wall.yml).
    def open_wall
      doing('The Wall')
      TTG::Wall.open(session)
    end

    # The mailbox: a letter to the sysops (ttg-common TTG::Feedback, in the
    # words of lib/content/feedback.yml); +kind+ skips the choice.
    def write_feedback(kind = nil)
      doing('Feedback')
      TTG::Feedback.open(session, kind: kind)
    end

    # The sysop's bell: a page, a kind of feedback.
    def page_sysop
      bell
      write_feedback(:page)
    end
  end
end
