# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # A menu of Global Discovery: a row an item, its label, a note, and a
      # count or a hint on the right. The arrows choose, RETURN takes the
      # item (its block runs; the menu comes back after), Q or Esc goes back.
      class MenuView
        include Style

        Item = Data.define(:label, :note, :action)

        def initialize(session, path, items)
          @session = session
          @path    = path
          @items   = items
          @index   = 0
        end

        def run
          loop do
            draw
            case key
            when :up then @index = (@index - 1) % @items.size
            when :down then @index = (@index + 1) % @items.size
            when :enter, :right then @items[@index].action.call
            when :escape, :left, 'q', 'Q' then return
            end
          end
        end

        private

        def draw
          lines = [crumbs(@path), rule, '', *visible_rows]
          lines.push('', "#{DIM}↑↓ choose   RETURN open   Q back#{RESET}")
          paint(lines)
        end

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
