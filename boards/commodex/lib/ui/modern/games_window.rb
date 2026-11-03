# frozen_string_literal: true

module UI
  module Modern
    # A list of games, the card of the one picked on the right; its buttons
    # open the about page, the tips, and the form for a tip.
    module GamesWindow
      extend BBS::Part

      window :games, :master_detail do
        empty 'No games here.'
        height(-6)
        title      { caption }
        list_width { [32, cols / 3].max }
        items      { games }
        label      :label
        detail     { |game, width| game_card(game, width) }
        on_pick    { |game| read_about(game) }
        meta(&:id)
        action('A&bout') { |game| read_about(game) }
        action('&Tips') { |game| show_tips(game) }
        action('A&dd a tip') { |game| add_tip(game) }
      end
    end
  end
end
