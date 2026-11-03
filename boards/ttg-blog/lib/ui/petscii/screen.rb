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
      FULL = BBS::Selector::COLORS.merge(hint: "#{CY}#{RV}").freeze

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

      # A numbered list filling the screen under its title bar; the keys of
      # +item_commands+ return <tt>[key, item]</tt> for the lit item.
      def pick(heading, items, empty: EMPTY, right: '', item_commands: {}, &label)
        return nothing(heading, empty, right: right) if items.empty?

        label ||= :to_s.to_proc
        title(heading, right)
        hint   = ['crsr/number  return: open', *item_commands.map { |k, v| "#{k}: #{v}" }, 'q: back'].join('  ')
        choice = BBS::Selector.list(session, items, width: cols - 1, height: footer_row - 2, fill: true,
                                                    hint: hint, colors: FULL, exits: { 'q' => nil },
                                                    item_exits: item_commands.keys.to_h { |k| [k, k] }) do |item|
          plain(label.call(item))
        end
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
        pages = view_pages(lines, actions)
        keys  = actions.to_h { |k, _| [k, k] }
        index = 0
        loop do
          view_page(heading, right, pages, index, actions)
          move = turn(keys, index, pages.size)
          return move.key if move.is_a?(Leave)

          index += move
        end
      end

      # A key that leaves the #view: +key+ is the action's, nil for none.
      Leave = Data.define(:key)

      # +question+ in the footer when the view has one, a yes/no row the
      # cursor moves along under it; elsewhere the question under the text.
      def confirm?(question, color)
        return super unless @at

        footer_choice(question, color, [%w[y yes], %w[n no]], back: 'n', index: 1) == 'y'
      end

      # +question+ in the footer, a row of +choices+ (<tt>[key, label]</tt>
      # pairs) the cursor moves along under it: the key taken, +back+ for
      # RUN/STOP or ←.
      def footer_choice(question, color, choices, back:, index: 0)
        footer_text(question, color)
        items  = choices.map { |k, label| BBS::Selector.item(label, key: k, value: k) }
        choice = BBS::Selector.new(session, items, width: cols - 1, across: true, index: index, back: back).run
        @at = [rows, 1]
        choice
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

      # The lines of a #view in pages, as many as fit over its footer.
      def view_pages(lines, actions)
        lines = fit(lines)
        lines = [" #{GR}#{EMPTY}#{LG}"] if lines.empty?
        lines.each_slice(view_rows(actions)).to_a
      end

      def view_rows(actions) = footer_row - 2 - (actions.empty? ? 0 : 1)

      # The keys of a page until one turns it or leaves the view: the step
      # (1 or -1), or a Leave.
      def turn(keys, index, count)
        last = index == count - 1
        loop do
          k = view_key
          return Leave.new(nil) if [:escape, :interrupt, 'q'].include?(k) || (k == :enter && last)
          return Leave.new(keys[k]) if keys.key?(k)

          step = step(k, index, last)
          return step unless step.zero?
        end
      end

      def view_key
        k = key
        k.is_a?(String) ? k.downcase : k
      end

      def step(k, index, last)
        case k
        when :enter, ' ', '+', :down, :right, :page_down then last ? 0 : 1
        when '-', :up, :left, :page_up then index.zero? ? 0 : -1
        else 0
        end
      end

      def view_page(heading, right, pages, index, actions)
        title(heading, right)
        pages[index].each { |l| puts l }
        (view_rows(actions) - pages[index].size).times { puts }
        puts " #{actions.map { |k, label| "#{YE}#{k.upcase}#{LG} #{label}" }.join('  ')}" if actions.any?
        write page_footer(pages, index)
        @at = [footer_row, cols]
      end

      def page_footer(pages, index)
        last = index == pages.size - 1
        keys = [last ? 'return: back' : 'return: more', ('-: before' unless index.zero?), ('q: back' unless last)]
        footer_bar(keys.compact.join('  '), pages.size > 1 ? "#{index + 1}/#{pages.size} " : '')
      end

      # +text+ on the two rows over the footer bar, and the cursor
      # at the start of the footer bar.
      def footer_text(text, color)
        cursor = BBS::Cursor.new(session, row: @at[0], col: @at[1])
        out    = +''
        lines  = footer_lines(text)
        lines.each_with_index do |line, i|
          out << cursor.move(footer_row - lines.size + i, 1) << " #{color}#{line.ljust(cols - 2)}#{LG}"
          cursor.wrote(cols - 1)
        end
        write(out << cursor.move(footer_row, 1))
      end

      # +text+ on two rows, at the bottom of them.
      def footer_lines(text)
        lines = wrap(plain(text), cols - 2).first(2)
        lines.unshift('') while lines.size < 2
        lines
      end
    end
  end
end
