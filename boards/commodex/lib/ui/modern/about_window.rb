# frozen_string_literal: true

module UI
  module Modern
    # The lead of a game's Wikipedia article, scrolling, with its licence and
    # address.
    module AboutWindow
      extend Rubbs::Modern::Part

      window :about, :info do
        maximizable true
        scroll      true
        height(-6)
        title       { game.title }
        width       { about_width }
        body        { about_body(summary) }
      end
    end
  end
end
