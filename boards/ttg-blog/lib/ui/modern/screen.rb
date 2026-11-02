# frozen_string_literal: true

module UI
  module Modern
    # The Screen on a modern terminal: the lists numbered, a page of them at
    # a time, picked by typing the number.
    class Screen < UI::Screen
      # A numbered list of +items+ by +label+; the item picked, or nil.
      # RETURN alone turns to the next page, round to the first. A key of
      # +item_commands+ asks for the number it works on: <tt>[key, item]</tt>.
      def pick(heading, items, empty: EMPTY, right: '', item_commands: {}, &label)
        return nothing(heading, empty, right: right) if items.empty?

        per   = page_size - 1
        pages = items.each_slice(per).to_a
        index = 0
        loop do
          list_page(heading, right, pages, index, per, item_commands, &label)
          answer = number(letters: item_commands.keys)
          return nil if answer.nil?
          if answer.is_a?(String)
            picked = command(answer, item_commands[answer], items)
            return picked if picked
          elsif answer.between?(1, items.size)
            return items[answer - 1]
          elsif answer.zero?
            index = (index + 1) % pages.size
          end
        end
      end

      private

      # <tt>[key, item]</tt> for the number typed after a command key; nil
      # when none.
      def command(key, name, items)
        write "#{DG}#{name} number#{LG} > "
        n = number
        n&.between?(1, items.size) ? [key, items[n - 1]] : nil
      end

      def list_page(heading, right, pages, index, per, commands, &label)
        title(heading, right)
        pages[index].each.with_index((index * per) + 1) do |item, n|
          puts "#{YE}#{n.to_s.rjust(3)}#{LG} #{BBS::FrameBuffer.clip_ansi(label.call(item).to_s, cols - 6)}"
        end
        extra = commands.map { |k, v| "  #{k}: #{v}" }.join
        write "\r\n#{DG}number#{more(pages, index)}#{extra}  q: back#{LG}\r\n> "
      end

      def more(pages, index)
        return '' if pages.size < 2

        " return: #{index + 1 < pages.size ? 'more' : 'top'}"
      end
    end
  end
end
