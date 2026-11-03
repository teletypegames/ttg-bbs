# frozen_string_literal: true

module UI
  module Modern
    # The approved tips of a game: who and when on the left, the tip on the
    # right, and a button for a new one.
    module TipsWindow
      extend BBS::Part

      window :tips, :master_detail do
        empty 'No tips yet. Add the first one!'
        height(-6)
        title      { "Tips: #{game.title}" }
        list_width 26
        items      { entries }
        label      { |tip| "#{tip.author} · #{tip.date}" }
        detail     { |tip| ["#{accent(tip.author)}#{dim(" · #{tip.date}")}", '', tip.text] }
        meta       { |tip| "tip ##{tip.id}" }
        action('A&dd a tip') { add_tip(game) }
      end
    end
  end
end
