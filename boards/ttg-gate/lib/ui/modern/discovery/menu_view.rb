# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # A menu of Global Discovery: a row an item, its label, a note, and a
      # count or a hint on the right. The arrows choose, RETURN takes the
      # item (its block runs; the menu comes back after), Q or Esc goes back.
      class MenuView < Screen
        Item = Data.define(:label, :note, :action)

        key(:up)   { @index = (@index - 1) % @items.size }
        key(:down) { @index = (@index + 1) % @items.size }
        key(:enter, :right) { @items[@index].action.call }
        key(:escape, :left, 'q', 'Q') { back }

        def initialize(path, items)
          super()
          @path  = path
          @items = items
          @index = 0
        end

        def lines
          [crumbs(@path), rule, '', *visible_rows, '', "#{DIM}↑↓ choose   RETURN open   Q back#{RESET}"]
        end

        private

        # The rows that fit, the chosen one among them.
        def visible_rows
          room  = rows - 1 - 6
          first = (@index - room + 1).clamp(0, [@items.size - room, 0].max)
          @items[first, room].each_with_index.map do |item, i|
            menu_row(item.label, item.note, label_width, lit: first + i == @index)
          end
        end

        # The longest label and a gap, at most half the width.
        def label_width = [@items.map { |i| i.label.length }.max.to_i + 2, width / 2].min
      end
    end
  end
end
