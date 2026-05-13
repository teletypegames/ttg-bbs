# frozen_string_literal: true

module UI
  module Windows
    # Split-view wiki browser. Left=titles, right=selected page content
    # (rendered with markdown-aware formatting).
    class Wiki
      def self.open(app, services:, category:, title:)
        items = services[:wiki].list(category)
        BBS::Windows::MasterDetail.open(app,
          title:         " #{title} ",
          items:         items,
          item_label:    ->(p) { p.title },
          list_width:    [32, app.cols / 3].max,
          empty_message: '  (no pages found)',
          close_button:  false,
          render_detail: ->(page, width) {
            text = services[:wiki].content(page.id)
            BBS::Markdown.to_lines(text, width: width - 1, theme: app.theme)
          },
          bottom_meta: ->(page) {
            "#{page.created_at.to_s[0, 10]}  #{services[:wiki].page_url(page.locale, page.path)}"
          }
        )
      end
    end
  end
end
