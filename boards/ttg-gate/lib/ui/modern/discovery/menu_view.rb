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
          label = [@items.map { |i| i.label.length }.max.to_i + 2, width / 2].min
          lines = [crumbs(@path), rule, '']
          room  = rows - 1 - 6
          first = (@index - room + 1).clamp(0, [@items.size - room, 0].max)
          @items[first, room].each_with_index do |item, i|
            lit = first + i == @index
            lines << "#{lit ? "#{SELECT}#{GREEN}▸ " : '  '}#{BOLD}#{fit(item.label, label)}#{RESET}" \
                     "#{SELECT if lit}#{DIM}#{fit(item.note, width - label - 2)}#{RESET}"
          end
          lines.push('', "#{DIM}↑↓ choose   RETURN open   Q back#{RESET}")
          paint(lines)
        end
      end
    end
  end
end
