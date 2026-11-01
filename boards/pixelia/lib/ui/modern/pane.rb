# frozen_string_literal: true

module UI
  module Modern
    # The size of a two-pane window: the height of the desktop, a list as
    # wide as the block says for the Application, and whether it maximizes.
    module Pane
      module_function

      def size(w, maximizable: true, &list_width)
        w.maximizable maximizable
        w.height     { |ctx| ctx[:app].rows - 6 }
        w.list_width { |ctx| list_width.call(ctx[:app]) }
      end
    end
  end
end
