# frozen_string_literal: true

module GamesPage
  def self.configure(tui)
    tui.page :games do
      enter { @page_title = 'GAME CATALOG'; @items = CATALOG.fetch; @item_sel = 0 }

      render do
        if @items.empty?
          text 'No games found.', x: CONT_X, y: CONT_Y, style: THEME[:normal]
        else
          game  = @items[@item_sel]
          links = game.external_links

          text "#{@item_sel + 1}/#{@items.size}  #{game.title}"[0, cont_w],
               x: CONT_X, y: CONT_Y, style: THEME[:bright]
          text "#{game.platform}  ·  #{game.author}"[0, cont_w],
               x: CONT_X, y: CONT_Y + 1, style: THEME[:normal]

          story_rows = cont_h - 4 - links.size
          wordwrap(game.story, cont_w).first(story_rows).each_with_index do |l, i|
            text l, x: CONT_X, y: CONT_Y + 3 + i, style: THEME[:normal]
          end

          link_y = CONT_Y + cont_h - links.size
          links.each_with_index do |lnk, i|
            text "#{tc(:label, lnk[:label])}  #{lnk[:url]}"[0, cont_w],
                 x: CONT_X, y: link_y + i
          end

          text '↑↓ navigate  q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
        end
      end

      nav :cycle
      key('r')     { reload }
      key('q')     { go :idle }
      key(:escape) { go :idle }
    end
  end
end
