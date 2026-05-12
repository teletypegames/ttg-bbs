# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Game catalog browser. Left=titles, right=card with story + links.
    def games(app, services:)
      cols = app.cols
      rows = app.rows
      w = cols - 4
      h = rows - 6
      window = BBS::Window.new(title: ' Game Catalog ')
      window.layout(3, 3, w, h)
      window.theme = app.theme

      games = services[:games].all

      list = BBS::Widgets::ListBox.new(
        items: games,
        label: ->(g) { "  #{g.title}".ljust(26) }
      )
      list_width = 30
      list.layout(window.bounds.x + 2, window.bounds.y + 2, list_width, h - 5)
      window.add(list)

      card = BBS::Widgets::ScrollView.new(lines: [])
      card_x = window.bounds.x + list_width + 4
      card_w = w - list_width - 7
      card.layout(card_x, window.bounds.y + 2, card_w, h - 7)
      window.add(card)

      load_card = lambda do
        game = list.selected_item
        if game.nil?
          card.lines = ['  (no games)']
          next
        end
        lines = []
        lines << "  \e[1;33m#{game.title}\e[0m"
        lines << "  \e[0;36m#{game.platform} · #{game.author}\e[0m"
        lines << ''
        wrap_para(game.desc.to_s, card_w - 4).each { |l| lines << "  #{l}" }
        lines << ''
        wrap_para(game.story.to_s, card_w - 4).each { |l| lines << "  #{l}" }
        lines << ''
        game.external_links.each do |link|
          lines << "  \e[0;37m#{link[:label].ljust(10)}\e[0m \e[1;36m#{link[:url]}\e[0m"
        end
        card.lines = lines
        card.scroll = 0
      end

      list.on_select = ->(_, _) { load_card.call }

      close = BBS::Widgets::Button.new(label: '&Close',
                                       on_click: ->(_) { app.close_window(window) })
      close.layout(window.bounds.x + w - 11, window.bounds.y + h - 2, 9, 1)
      window.add(close)

      load_card.call
      window.reset_focus
      window.focus_manager.focus(list)
      app.open_window(window)
      window
    end

    def wrap_para(text, width)
      return [] if text.empty?
      words = text.split
      lines = []
      cur = +''
      words.each do |w|
        if cur.empty?
          cur << w
        elsif cur.length + 1 + w.length <= width
          cur << ' ' << w
        else
          lines << cur.dup
          cur = +w
        end
      end
      lines << cur unless cur.empty?
      lines
    end
  end
end
