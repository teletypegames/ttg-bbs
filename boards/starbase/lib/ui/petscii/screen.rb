# frozen_string_literal: true

module UI
  module Petscii
    BBS::Petscii::Colors.install(self)
    COLS  = BBS::Petscii::Screen::COLS
    WIDTH = BBS::Petscii::Screen::WIDTH

    # The 40×25 screen of one call: rubbs' Petscii::Screen (title bar, pages, Selector lists and
    # menus). The board's own screen helpers go here.
    class Screen < BBS::Petscii::Screen
    end
  end
end
