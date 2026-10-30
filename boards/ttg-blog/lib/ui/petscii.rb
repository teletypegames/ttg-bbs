# frozen_string_literal: true

require_relative 'board'

module UI
  # The blog on a Commodore 64: the line-by-line Board in PETSCII on a 40×25
  # screen, under a masthead in reversed spaces.
  module Petscii
    COLS = 40
    ROWS = 25
    PAGE = ROWS - 5

    LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

    def self.logo
      Board.logo_bits.each_with_index.map do |row, i|
        "  #{LOGO_COLORS[i]}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
      end
    end

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule, "  #{WH}#{Board::MOTTO}#{LG}"]
    end

    # A post on a C64, as lines of ANSI: the title bar, then the post as the
    # board pages it, PAGE lines a screenful. The web draws it in C64 colours.
    def self.post_screen(blog, post)
      screen = Screen.new(nil, cols: COLS, rows: ROWS)
      lines  = screen.fit(Board.post_lines(blog, post, width: screen.width))
      [screen.title_bar(blog.category(post.category).name.upcase, "#{blog.total} posts "), *lines]
    end

    def self.flow(blog)
      Board.flow(blog, face: 'petscii') { |session| [Screen.new(session, cols: COLS, rows: ROWS), masthead] }
    end
  end
end
