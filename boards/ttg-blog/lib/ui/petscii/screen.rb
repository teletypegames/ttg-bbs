# frozen_string_literal: true

module UI
  module Petscii
    # The Screen on a Commodore 64, every view the whole 40×25: a title bar
    # on the first row and a footer bar on the last but one that tells the
    # keys of the view. A post is read under a footer that stays on every
    # page, and the questions about it are asked in the footer, over the
    # post. The last row stays empty, so nothing scrolls the screen.
    class Screen < UI::Screen
      # The menus with their hint row as a footer bar, like the title bar.
      FULL = MENU.merge(hint: "#{CY}#{RV}").freeze

      # The row of the footer bar.
      def footer_row = rows - 1

      def cls
        @at = nil
        super
      end

      # A cursor menu from the cursor's row down to the footer bar: the
      # rows under the items stay blank, the about row and the hint as a bar
      # stand at the bottom.
      def full_menu(items, top:, hint:, back: nil, index: nil)
        about  = items.any?(&:about) ? 1 : 0
        choice = BBS::Selector.new(session, items, width: cols - 1, height: footer_row - top + 1 - about - 1,
                                                   fill: true, index: index, hint: hint, back: back,
                                                   colors: FULL).run
        @at = [rows, 1]
        choice
      end

      # A numbered list filling the screen under its title bar.
      def pick(heading, items, empty: EMPTY, right: '', &label)
        label ||= :to_s.to_proc
        title(heading, right)
        if items.empty?
          say(empty, GR)
          pause
          return nil
        end
        choice = BBS::Selector.list(session, items, width: cols - 1, height: footer_row - 2, fill: true,
                                                    hint: 'crsr/number  return: open  q: back', colors: FULL,
                                                    exits: { 'q' => nil }) { |item| plain(label.call(item)) }
        @at = [rows, 1]
        choice
      end

      # Every page of text in the #view.
      def page(heading, lines, right: '', **)
        view(heading, lines, right: right)
        nil
      end

      # +lines+ a screenful at a time under the title bar of +heading+, with
      # the footer bar on every page: RETURN, + or CRSR down/right turn to the
      # next page, - or CRSR up/left back, q, ← or RUN/STOP leave, RETURN on
      # the last page too. +actions+, <tt>[key, label]</tt> pairs, stand on a
      # row over the footer, and their keys leave with the key.
      #
      # Returns the key of an action, or nil.
      def view(heading, lines, right: '', actions: [])
        lines = fit(lines)
        lines = [" #{GR}#{EMPTY}#{LG}"] if lines.empty?
        size  = footer_row - 2 - (actions.empty? ? 0 : 1)
        pages = lines.each_slice(size).to_a
        keys  = actions.to_h { |k, _| [k, k] }
        index = 0
        loop do
          view_page(heading, right, pages, index, size, actions)
          loop do
            k    = key
            last = index == pages.size - 1
            k    = k.downcase if k.is_a?(String)
            return nil if [:escape, :interrupt, 'q'].include?(k) || (k == :enter && last)
            return keys[k] if keys.key?(k)

            turn = case k
                   when :enter, ' ', '+', :down, :right, :page_down then last ? 0 : 1
                   when '-', :up, :left, :page_up then index.zero? ? 0 : -1
                   else 0
                   end
            next if turn.zero?

            index += turn
            break
          end
        end
      end

      # +question+ in the footer when the view has one, a yes/no row the
      # cursor moves along under it; elsewhere the question under the text.
      def confirm?(question, color)
        return super unless @at

        footer_text(question, color)
        items = [BBS::Selector.item('yes', key: 'y', value: 'y'), BBS::Selector.item('no', key: 'n', value: 'n')]
        choice = BBS::Selector.new(session, items, width: cols - 1, across: true, index: 1, back: 'n',
                                                   colors: MENU).run
        @at = [rows, 1]
        choice == 'y'
      end

      # +text+ in the footer when the view has one, until a key.
      def notice(text, color, gap: true)
        return super unless @at

        footer_text(text, color)
        write footer_bar('return: ok')
        @at = [footer_row, cols]
        key
      end

      # A reversed bar like the title bar, out of the last column, so the
      # cursor stays on its row: +text+ at the left, +right+ at the right.
      def footer_bar(text, right = '')
        room = cols - 1 - right.length
        "#{CY}#{RV}#{" #{plain(text)}".ljust(room)[0, room]}#{right}#{RO}#{LG}"
      end

      private

      def view_page(heading, right, pages, index, size, actions)
        title(heading, right)
        chunk = pages[index]
        chunk.each { |l| puts l }
        (size - chunk.size).times { puts }
        puts " #{GR}editor#{LG} #{actions.map { |k, label| "#{YE}#{k.upcase}#{LG} #{label}" }.join('  ')}" if actions.any?
        last = index == pages.size - 1
        keys = [last ? 'return: back' : 'return: more', ('-: before' unless index.zero?), ('q: back' unless last)]
        write footer_bar(keys.compact.join('  '), pages.size > 1 ? "#{index + 1}/#{pages.size} " : '')
        @at = [footer_row, cols]
      end

      # +text+ on the two rows over the footer bar, and the cursor
      # at the start of the footer bar.
      def footer_text(text, color)
        lines = wrap(plain(text), cols - 2).first(2)
        lines.unshift('') while lines.size < 2
        cursor = BBS::Cursor.new(session, row: @at[0], col: @at[1])
        out    = +''
        lines.each_with_index do |line, i|
          out << cursor.move(footer_row - lines.size + i, 1) << " #{color}#{line.ljust(cols - 2)}#{LG}"
          cursor.wrote(cols - 1)
        end
        write(out << cursor.move(footer_row, 1))
      end
    end
  end
end
