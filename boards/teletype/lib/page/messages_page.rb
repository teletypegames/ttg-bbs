# frozen_string_literal: true

module MessagesPage
  def self.configure(tui)
    tui.page :messages do
      enter do
        @page_title = 'MESSAGES'
        @items  = MESSAGES.last(30).map { |m| "#{tc(:label, m.timestamp)} #{tc(:bright, m.username)}: #{m.text}" }
        @scroll = 0
      end

      render do
        (@items[@scroll, cont_h] || []).each_with_index do |line, i|
          text line[0, cont_w], x: CONT_X, y: CONT_Y + i
        end
        text "#{@items.size} msg(s)  ↑↓ scroll  q back",
             x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
      end

      nav :scroll, content: -> { @items }, window: -> { cont_h }
      key('r')     { reload }
      key('q')     { go :idle }
      key(:escape) { go :idle }
    end
  end
end
