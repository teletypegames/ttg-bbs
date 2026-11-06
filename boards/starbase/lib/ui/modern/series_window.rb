# frozen_string_literal: true

module UI
  module Modern
    # The series and the films: the titles on the left, the picked one's
    # years and counts on the right; Enter opens its episodes.
    module SeriesWindow
      extend Rubbs::Modern::Part

      window :series, :master_detail do
        title 'Series'
        empty 'The catalog is empty.'
        list_width { [34, cols / 3].max }
        items      { catalog.series }
        label      :short_title
        detail     { |s, width| [bright(s.title), '', *card(Card.series(s, catalog.episodes(s), catalog.seasons(s)), width)] }
        meta       { 'Enter opens the episodes' }
        on_pick    { |s| open_series(s) }
        action('Episodes') { |s| open_series(s) }
        action('Article') { |s| read(s.ma || s.title) }
      end
    end
  end
end
