# frozen_string_literal: true

require_relative 'board'
require_relative 'petscii/screen'
require_relative 'petscii/board'

module UI
  # The blog on a Commodore 64: the line-by-line board in PETSCII on a 40×25
  # screen. It works on the same TtgblogBBS as the modern face.
  module Petscii
    COLS = 40
    ROWS = 25
    PAGE = ROWS - 5

    # A post on a C64, as lines of ANSI: the title bar, then the post as the
    # board pages it, PAGE lines a screenful. The web draws it in C64 colours.
    def self.post_screen(bbs, post)
      screen = Screen.new(nil, cols: COLS, rows: ROWS)
      lines  = screen.fit(UI::Board.post_lines(bbs.categories, post, width: screen.width))
      [screen.title_bar(bbs.categories.find(post.category).name.upcase, "#{bbs.posts.total(published: true)} posts "),
       *lines]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          board = Board.new(bbs, Board.screen(runner.session), ctx)
          board.run
          board.goodbye
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
