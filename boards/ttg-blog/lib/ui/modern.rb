# frozen_string_literal: true

require_relative 'board'

module UI
  # The blog on a modern terminal (ANSI colours, UTF-8): the line-by-line
  # board on the caller's window, up to 80 columns, under a masthead in half
  # blocks, the main menu a list of keys typed at a prompt.
  class Modern < Board
    masthead do
      gap
      rule
      art(BBS::BlockFont.half_blocks(LOGO).map { |l| "  #{YE}#{l}#{LG}" })
      rule
      art "  #{WH}#{MOTTO}#{LG}"
    end

    def make_screen(session)
      BBS::Petscii::Screen.new(session, cols: session.term_cols.clamp(40, 80), rows: session.term_rows.clamp(16, 60))
    end

    # The main menu as a list of keys, one typed at the prompt.
    def menu(items, **)
      items.each { |i| puts " #{YE}#{i.key.upcase}#{LG} #{i.label}" }
      choose("\r\n #{WH}ttgblog#{LG}> ", items.map(&:key))
    end
  end
end
