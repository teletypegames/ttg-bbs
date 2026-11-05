# frozen_string_literal: true

module UI
  module Modern
    # The browser: the page tree on the left, the picked page as markdown on
    # the right; a private page stays a notice but for a supervisor.
    module BrowserWindow
      extend Rubbs::Modern::Part

      window :browser, :master_detail do
        title 'Teletype Games Wiki'
        close_button false
        maximized    true
        list_width 32
        empty '  (no pages)'
        items { wiki.pages }
        label { |page| "#{'  ' * (page.depth - 1)}#{page.title}#{' *' if locked?(page)}" }
        detail { |page, width| markdown(page_text(page), width) }
        meta { |page| " #{page.route}   #{locked?(page) ? 'SUPERVISOR ONLY' : "updated #{page.updated_at}"}" }
      end
    end
  end
end
