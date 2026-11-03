# frozen_string_literal: true

module UI
  module Modern
    # An article: its sections on the left, the picked one as Markdown on the
    # right, the lead with the title it was redirected from.
    module ArticleWindow
      extend BBS::Part

      window :article, :master_detail do
        title      { article.title }
        list_width { [26, cols / 4].max }
        items      { article.sections }
        label      :title
        detail do |section, width|
          lines = markdown("# #{section.title}\n\n#{section.markdown}", width)
          next lines unless section == article.sections.first && article.redirected_from

          lines.insert(1, dim("(Redirected from #{article.redirected_from})"))
        end
        meta { "#{article.url} · CC BY-SA" }
        action('QR code') { qr article.short_url, title: 'Scan the article' }
      end
    end
  end
end
