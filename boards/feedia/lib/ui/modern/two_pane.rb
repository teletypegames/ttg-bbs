# frozen_string_literal: true

module UI
  module Modern
    # The size of the feed and channel windows: as tall as the masthead
    # leaves free, a third of the width (at least 30 columns) the list.
    module TwoPane
      module_function

      def size(w)
        w.maximizable true
        w.height     { |ctx| ctx[:app].rows - 8 }
        w.list_width { |ctx| [30, ctx[:app].cols / 3].max }
      end
    end
  end
end
