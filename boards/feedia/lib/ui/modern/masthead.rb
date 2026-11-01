# frozen_string_literal: true

module UI
  module Modern
    # The desktop of a new call: a newspaper's masthead over the feed list.
    module Masthead
      module_function

      # The masthead's two rows under an empty one: the feed windows are four
      # rows shorter than the desktop's default, so three rows stay free above
      # them and three below.
      def draw(app)
        mark = ((app.cols - Logo::HALF_BLOCKS.first.length) / 2) + 1
        Logo::HALF_BLOCKS.zip(left, right(app)).each.with_index(3) { |line, y| row(app, line, mark, y) }
        app.desktop_label('─── All the news that fits in 80 columns ───', :text_dim, 1, app.rows - 2, app.cols, align: :center)
        app.statusbar.right_text = app.status_text
        app.feed_list
      end

      # One row of the masthead: the logo's row between its two ears.
      def row(app, line, mark, y)
        logo, left, right = line
        ear = mark - 4
        app.desktop_label(logo, :accent, mark, y, logo.length)
        app.desktop_label(left, :text_dim, 3, y, ear)
        app.desktop_label(right, :text_dim, mark + logo.length + 2, y, ear, align: :right)
      end

      def left = ['VOL. I · NO. 2327', 'THE TELNET EDITION']

      def right(app) = [Time.now.strftime('%A %-d %b %Y').upcase, "#{app.services[:feeds].list.size} FEEDS · NO CHARGE"]
    end
  end
end
