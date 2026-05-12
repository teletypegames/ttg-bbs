# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Split-view wiki browser. Left=titles, right=selected page content.
    def wiki(app, services:, category:, title:)
      cols = app.cols
      rows = app.rows
      w = cols - 4
      h = rows - 6
      window = BBS::Window.new(title: " #{title} ")
      window.layout(3, 3, w, h)
      window.theme = app.theme

      items = services[:wiki].list(category)

      list = BBS::Widgets::ListBox.new(
        items: items,
        label: ->(p) { "  #{p.title}".ljust(28) }
      )
      list_width = [32, (w / 3)].max
      list.layout(window.bounds.x + 2, window.bounds.y + 2, list_width, h - 5)
      window.add(list)

      preview = BBS::Widgets::ScrollView.new(lines: [])
      preview.layout(window.bounds.x + list_width + 4, window.bounds.y + 2,
                     w - list_width - 7, h - 5)
      window.add(preview)

      meta = BBS::Widgets::Label.new(text: '', style_key: :input_label)
      meta.layout(window.bounds.x + 2, window.bounds.y + h - 2, w - 4, 1)
      window.add(meta)

      load_preview = lambda do
        page = list.selected_item
        next unless page
        meta.text = "#{page.created_at.to_s[0, 10]}  #{services[:wiki].page_url(page.locale, page.path)}"
        text = services[:wiki].content(page.id)
        preview.lines = wrap_md(text, preview.bounds.width - 1)
        preview.scroll = 0
      end

      list.on_select = ->(_, _) { load_preview.call }

      if items.empty?
        preview.lines = ['  (no pages found)']
      else
        load_preview.call
      end

      window.reset_focus
      window.focus_manager.focus(list)
      app.open_window(window)
      window
    end

    def wrap_md(text, width)
      stripped = text.to_s
                   .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
                   .gsub(/[#*_`~>|\\]/, '')
                   .gsub(/\r?\n+/, ' ')
                   .strip
      words = stripped.split
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
      lines.empty? ? [''] : lines
    end
  end
end
