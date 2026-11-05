# frozen_string_literal: true

module UI
  module Modern
    # The packs of a year on the left, the one picked on the right.
    module PacksWindow
      extend Rubbs::Modern::Part

      window :packs, :master_detail do
        title      { "16colo.rs #{year.year}" }
        list_width { [28, cols / 3].max }
        items      { packs }
        label      :name
        detail     { |p| [bright(p.name), accent(p.credits), paint(:label, p.year), '', dim(gallery.pack_url(p))] }
        meta       { 'Enter opens the pack' }
        on_pick    { |p| open_pack(p) }
        height(-6)
      end
    end
  end
end
