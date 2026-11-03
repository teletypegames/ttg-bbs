# frozen_string_literal: true

module UI
  module Petscii
    BBS::Petscii::Colors.install(self)

    COLS  = BBS::Petscii::Screen::COLS
    WIDTH = BBS::Petscii::Screen::WIDTH

    # The 40×25 screen of one call: the shared one of rubbs
    # (BBS::Petscii::Screen), plain text included.
    class Screen < BBS::Petscii::Screen
    end
  end
end
