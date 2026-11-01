# frozen_string_literal: true

module UI
  module Modern
    # The desktop of the modern face: the logo, the tagline, the clock and
    # the size of the catalog on the statusbar.
    module Desktop
      TAGLINE = '─── the classic literature vault · books from Project Gutenberg ───'

      def open_desktop
        mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
        Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
        desktop_label(TAGLINE, :text_dim, 1, rows - 2, cols, align: :center)
        statusbar.right_text = status_text
        classics
      end

      def status_text
        count = library.count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
        books = library.ready? ? "#{count} books" : 'preparing the catalog…'
        "#{books} │ #{Time.now.strftime('%H:%M')}"
      end

      def desktop_label(text, style, x, y, width, align: :left)
        label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
        label.layout(x, y, width, 1)
        add(label)
      end
    end
  end
end
