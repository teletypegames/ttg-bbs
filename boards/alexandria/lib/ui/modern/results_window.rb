# frozen_string_literal: true

module UI
  module Modern
    # The search results: the titles on the left, the picked one's snippet
    # on the right; Enter opens the article.
    module ResultsWindow
      extend Rubbs::Modern::Part

      window :results, :master_detail do
        title      { "Search: #{query}" }
        list_width { [30, cols / 3].max }
        items      { results }
        label      :title
        detail     { |r| [bright(r.title), '', "…#{r.snippet}…"] }
        meta       { |r| "#{r.words} words · Enter opens it" }
        on_pick    { |r| read(r.title) }
        action('Open') { |r| read(r.title) }
      end
    end
  end
end
