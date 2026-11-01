# frozen_string_literal: true

module UI
  module Modern
    # The browser: the page tree on the left, the picked page as markdown on
    # the right; a private page stays a notice until the call is unlocked.
    module BrowserWindow
      LOCKED = "# Supervisor only\n\nThis page is private. Unlock it via **Wiki > Supervisor login**."

      module_function

      def install(app)
        app.window(:browser, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title ' Teletype Games Wiki '
        w.maximizable true
        w.close_button false
        w.list_width 32
        w.empty_message '  (no pages)'
        w.items { |ctx| ctx[:wiki].pages }
        w.item_label { |page, ctx| label(page, ctx[:app]) }
        w.render_detail { |page, width, ctx| detail(page, width, ctx) }
        w.bottom_meta { |page, ctx| meta(page, ctx[:app]) }
      end

      def locked?(page, app) = page.private? && !app.unlocked?

      def label(page, app)
        "#{'  ' * (page.depth - 1)}#{page.title}#{' *' if locked?(page, app)}"
      end

      def detail(page, width, ctx)
        markdown = locked?(page, ctx[:app]) ? LOCKED : ctx[:wiki].page_markdown(page)
        BBS::Markdown.to_lines(markdown, width: width, theme: ctx[:app].theme)
      end

      def meta(page, app)
        locked?(page, app) ? " #{page.route}   SUPERVISOR ONLY" : " #{page.route}   updated #{page.updated_at}"
      end
    end
  end
end
