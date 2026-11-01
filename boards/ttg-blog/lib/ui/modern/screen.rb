# frozen_string_literal: true

module UI
  module Modern
    # The Screen on a modern terminal: the lists numbered, a page of them at
    # a time, picked by typing the number.
    class Screen < UI::Screen
      # A numbered list of +items+ by +label+; the item picked, or nil.
      # RETURN alone turns to the next page, round to the first.
      def pick(heading, items, empty: EMPTY, right: '', &label)
        return nothing(heading, empty, right: right) if items.empty?

        per   = page_size - 1
        pages = items.each_slice(per).to_a
        index = 0
        loop do
          list_page(heading, right, pages, index, per, &label)
          answer = number
          return nil if answer.nil?
          return items[answer - 1] if answer.between?(1, items.size)

          index = (index + 1) % pages.size if answer.zero?
        end
      end

      private

      def list_page(heading, right, pages, index, per, &label)
        title(heading, right)
        pages[index].each.with_index((index * per) + 1) do |item, n|
          puts "#{YE}#{n.to_s.rjust(3)}#{LG} #{BBS::FrameBuffer.clip_ansi(label.call(item).to_s, cols - 6)}"
        end
        write "\r\n#{DG}number#{more(pages, index)}  q: back#{LG}\r\n> "
      end

      def more(pages, index)
        return '' if pages.size < 2

        " return: #{index + 1 < pages.size ? 'more' : 'top'}"
      end
    end
  end
end
