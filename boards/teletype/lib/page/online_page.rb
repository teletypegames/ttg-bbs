# frozen_string_literal: true

module OnlinePage
  def self.configure(tui)
    tui.page :online do
      enter { @page_title = 'ONLINE USERS'; @items = ONLINE.snapshot.sort.map { |_, name| name } }

      render do
        @items.each_with_index do |uname, i|
          you = uname == @username ? tc(:normal, ' ← you') : ''
          text tc(:bright, uname) + you, x: CONT_X, y: CONT_Y + i
        end
        text "#{@items.size} user(s) online  q back",
             x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
      end

      key('r')     { reload }
      key('q')     { go :idle }
      key(:escape) { go :idle }
    end
  end
end
