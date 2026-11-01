# frozen_string_literal: true

module UI
  module Modern
    # The Screen on a modern terminal: the lists numbered, a page of them at
    # a time, picked by typing the number.
    class Screen < UI::Screen
      # A numbered list of +items+ by +label+; the item picked, or nil.
      def pick(heading, items, empty: EMPTY, right: '', &label)
        if items.empty?
          title(heading, right)
          say(empty, GR)
          pause
          return nil
        end
        per   = page_size - 1
        pages = items.each_slice(per).to_a
        index = 0
        loop do
          title(heading, right)
          pages[index].each_with_index do |item, i|
            n = (index * per) + i + 1
            puts "#{YE}#{n.to_s.rjust(3)}#{LG} #{BBS::FrameBuffer.clip_ansi(label.call(item).to_s, cols - 6)}"
          end
          more = if pages.size > 1
                   " return: #{index + 1 < pages.size ? 'more' : 'top'}"
                 else
                   ''
                 end
          write "\r\n#{DG}number#{more}  q: back#{LG}\r\n> "
          answer = number
          if answer.nil?
            return nil
          elsif answer.zero?
            index = (index + 1) % pages.size
          elsif answer <= items.size
            return items[answer - 1]
          end
        end
      end
    end
  end
end
