# frozen_string_literal: true

module UI
  module Petscii
    BBS::Petscii::Colors.install(self)

    COLS  = BBS::Petscii::Screen::COLS
    WIDTH = BBS::Petscii::Screen::WIDTH

    # The 40×25 screen of one call: rubbs' C64 screen (BBS::Petscii::Screen),
    # where ← and RUN/STOP answer a question with n.
    class Screen < BBS::Petscii::Screen
      def choose(prompt, keys, back: 'n') = super
    end
  end
end
