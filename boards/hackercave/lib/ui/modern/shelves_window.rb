# frozen_string_literal: true

module UI
  module Modern
    # The shelves on the left (the board's own, the series, the statuses,
    # the decades, the newest), what a shelf is on the right; Enter opens
    # its RFCs.
    module ShelvesWindow
      extend Rubbs::Modern::Part

      window :shelves, :master_detail do
        title 'Shelves'
        height     { rows - 8 }
        list_width { [30, (cols / 2) - 4].min }
        items      { shelves }
        label      { |s| shelf_label(s) }
        empty 'No shelves yet.'
        detail     { |s| [bright(shelf_label(s)), accent("#{s.count} RFCs"), '', s.about, '', dim(shelf_note(s))] }
        meta       { 'Enter opens the shelf' }
        on_pick    { |s| open_entries(s) }
        action('Open') { |s| open_entries(s) }
      end

      helpers do
        def shelf_label(shelf) = shelf.kind == :series ? "#{shelf.name} series" : shelf.name

        def shelf_note(shelf)
          case shelf.kind
          when :curated then 'The board\'s own shelf.'
          when :status, :decade then "At most #{LibraryService::SHELF_LIMIT} are listed; search for the rest."
          else 'From the index of the RFC Editor.'
          end
        end
      end
    end
  end
end
