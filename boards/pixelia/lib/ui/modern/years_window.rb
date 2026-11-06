# frozen_string_literal: true

module UI
  module Modern
    # The years of 16colo.rs on the left, the one picked on the right.
    module YearsWindow
      extend Rubbs::Modern::Part

      ABOUT = '16colo.rs keeps the art packs of the ANSI and ASCII scene, year by year, as the groups released ' \
              'them. Pixelia reads them from its public API and draws each piece here, in its 16 colours.'

      window :years, :master_detail do
        title       '16colo.rs'
        maximizable false
        list_width  24
        items       { years }
        label       { |y| "#{y.year}  #{y.packs.to_s.rjust(4)} packs" }
        detail do |y|
          [bright(y.year), accent("#{y.packs} art packs"), '', ABOUT, '', dim("#{gallery.site_url}/year/#{y.year}")]
        end
        meta        { 'Enter opens the year' }
        on_pick     { |y| open_year(y) }
        height(-6)
      end
    end
  end
end
