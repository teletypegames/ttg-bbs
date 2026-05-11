# frozen_string_literal: true

module PageViewPage
  def self.configure(tui)
    tui.page :page_view do
      render do
        text @page_meta[0, cont_w], x: CONT_X, y: CONT_Y, style: THEME[:normal]
        (@detail[@scroll, cont_h - 2] || []).each_with_index do |l, i|
          text l[0, cont_w], x: CONT_X, y: CONT_Y + 2 + i, style: THEME[:normal]
        end
        text "#{@scroll + 1}/#{@detail.size}  ↑↓ scroll  q back",
             x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
      end

      nav :scroll, content: -> { @detail }, window: -> { cont_h - 2 }
      key('q')     { @scroll = 0; go(@prev_page || :idle) }
      key(:escape) { @scroll = 0; go(@prev_page || :idle) }
    end
  end
end
