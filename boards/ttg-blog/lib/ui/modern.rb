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

    def initialize(session, context = {}, board = nil)
      super
      @screen = BBS::Petscii::Screen.new(session, cols: session.term_cols.clamp(40, 80),
                                                  rows: session.term_rows.clamp(16, 60))
    end

    private

    # The main menu, under the masthead the first time and under the title
    # bar after.
    def main_menu_choice
      home if @menu_shown
      @menu_shown = true
      puts
      items = menu_items
      items.each { |i| puts " #{YE}#{i.key.upcase}#{LG} #{i.label}" }
      key = choose("\r\n #{WH}ttgblog#{LG}> ", items.map(&:key))
      take(items.find { |i| i.key == key }.value)
    end
  end
end
