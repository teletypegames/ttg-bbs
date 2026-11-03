# frozen_string_literal: true

module UI
  module Modern
    # The shelves: the shelf list, a shelf's about and address on the right;
    # Enter opens its titles.
    module ShelvesWindow
      extend BBS::Part

      window :shelves, :master_detail do
        title 'Shelves'
        empty 'No shelves are configured.'
        list_width { [30, cols / 3].max }
        items      { catalog.shelves }
        label      :name
        detail     { |shelf| [bright(shelf.name), '', shelf.about, '', dim("#{catalog.url(shelf)}/")] }
        meta       { 'Enter opens the shelf' }
        on_pick    { |shelf| open_shelf(shelf) }
        height(-8)
        action('Open') { |shelf| open_shelf(shelf) }
      end
    end
  end
end
