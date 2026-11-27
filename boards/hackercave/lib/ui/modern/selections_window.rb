# frozen_string_literal: true

module UI
  module Modern
    # The selections on the left (the board's own, the series, the statuses,
    # the decades, the newest), what a selection is on the right; Enter opens
    # its RFCs.
    module SelectionsWindow
      extend Rubbs::Modern::Part

      window :selections, :master_detail do
        title 'Selections'
        height     { rows - 8 }
        list_width { [30, (cols / 2) - 4].min }
        items      { selections }
        label      { |s| selection_label(s) }
        empty 'No selections yet.'
        detail     { |s| [bright(selection_label(s)), accent("#{s.count} RFCs"), '', s.about, '', dim(selection_note(s))] }
        meta       { 'Enter opens the selection' }
        on_pick    { |s| open_entries(s) }
        action('Open') { |s| open_entries(s) }
      end

      helpers do
        def selection_label(selection) = selection.kind == :series ? "#{selection.name} series" : selection.name

        def selection_note(selection)
          case selection.kind
          when :curated then 'The board\'s own selection.'
          when :status, :decade then "At most #{LibraryService::SELECTION_LIMIT} are listed; search for the rest."
          else 'From the index of the RFC Editor.'
          end
        end
      end
    end
  end
end
