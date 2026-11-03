# frozen_string_literal: true

module UI
  module Modern
    # A Memory Alpha article: its sections on the left, the picked one as
    # Markdown on the right, the lead with the title it was redirected from.
    module ArticleWindow
      module_function

      def install(app)
        app.window(:article, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         { |ctx| " #{ctx[:article].title} " }
        w.list_width    { |ctx| [26, ctx[:app].cols / 4].max }
        w.items         { |ctx| ctx[:article].sections }
        w.item_label    { |s, _ctx| s.title }
        w.render_detail { |s, width, ctx| detail(ctx[:article], s, width, ctx[:app]) }
        w.bottom_meta   { |_s, ctx| "#{ctx[:article].url} · CC BY-NC" }
        qr_action(w)
      end

      def qr_action(w)
        w.action(label: '&QR code') do |_win, ctx|
          ctx[:app].show_qr(ctx[:article])
          :keep
        end
      end

      def detail(article, section, width, app)
        lines = app.markdown("# #{section.title}\n\n#{section.markdown}", width)
        return lines unless section == article.sections.first && article.redirected_from

        t = app.theme
        lines.insert(1, "#{t[:text_dim]}(Redirected from #{article.redirected_from})#{t[:text]}")
      end
    end
  end
end
