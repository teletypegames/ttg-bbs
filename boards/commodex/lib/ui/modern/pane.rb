# frozen_string_literal: true

module UI
  module Modern
    # The frame the list windows share: titled by what opened them, as tall
    # as the desktop, the list a third of the width, and a full-screen zoom.
    module Pane
      module_function

      def size(w)
        w.maximizable true
        w.title      { |ctx| ctx[:title] }
        w.height     { |ctx| ctx[:app].rows - 6 }
        w.list_width { |ctx| [32, ctx[:app].cols / 3].max }
      end
    end
  end
end
