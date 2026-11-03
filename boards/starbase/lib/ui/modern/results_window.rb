# frozen_string_literal: true

module UI
  module Modern
    # The search results: the titles on the left, the picked one's size on
    # the right; Enter opens the article.
    module ResultsWindow
      extend BBS::Part

      window :results, :master_detail do
        title      { "Library computer: #{query}" }
        list_width { [34, cols / 3].max }
        items      { results }
        label      :title
        detail     { |r| [bright(r.title), '', dim("#{r.words} words on Memory Alpha")] }
        meta       { 'Enter opens the article' }
        on_pick    { |r| read(r.title) }
        action('Open') { |r| read(r.title) }
      end
    end
  end
end
