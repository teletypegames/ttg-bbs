# frozen_string_literal: true

module WikiListPage
  def self.configure(tui, name, category:, title:)
    tui.page name do
      enter do
        @page_title = title
        @items      = WIKI.list(category)
        @item_sel   = 0
        @scroll     = 0
      end

      render { wiki_list_render }

      nav :list, window: -> { cont_h - 3 }
      key(:enter)  { open_wiki_page(back: name) }
      key('r')     { reload }
      key('q')     { go :idle }
      key(:escape) { go :idle }
    end
  end
end
