# frozen_string_literal: true

module IdlePage
  def self.configure(tui)
    tui.page :idle do
      enter { @page_title = 'TELETYPE BBS' }

      render do
        text 'Navigate the menu with ↑↓, select with Enter.',
             x: CONT_X, y: CONT_Y + cont_h / 2, style: THEME[:normal]
      end

      nav :menu, size: MENU_ITEMS.size
      key(:enter) do
        case MENU_ITEMS[@menu_sel]
        when 'Messages'     then go :messages
        when 'Post Message' then go :new_msg
        when 'Blog Posts'   then go :blog
        when 'HowTo Guides' then go :howto
        when 'Game Catalog' then go :games
        when 'Online Users' then go :online
        when 'System Info'  then go :sysinfo
        when 'Exit'         then :halt
        end
      end
      key('q')     { :halt }
      key(:escape) { :halt }
    end
  end
end
