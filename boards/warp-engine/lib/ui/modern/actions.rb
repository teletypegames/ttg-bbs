# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the modern Application: opening the windows, a
    # download, the desktop.
    module Actions
      NO_ANSWER = 'The archive did not answer. Try again later.'

      def catalog = services[:catalog]

      def shelf_list = open_window(:shelves)

      def open_shelf(shelf)
        titles = read_shelf(shelf)
        return BBS::Dialogs.message(self, NO_ANSWER, title: ' Shelf ') unless titles

        open_window(:titles, shelf: shelf, titles: titles)
      end

      def reload(window, shelf)
        titles = read_shelf(shelf, fresh: true)
        return BBS::Dialogs.message(self, NO_ANSWER, title: ' Reload ') unless titles

        window.replace_items(titles)
      end

      def download(title, protocol)
        data = with_loading("Fetching #{title.file}…") { catalog.fetch(title) }
        return tell(Transfer.refusal(data, title)) if data.is_a?(Symbol)

        result = with_line { |session| transfer(session, title, protocol, data) }
        catalog.downloaded(title, protocol) if result == :ok
        tell(Transfer.result(result, protocol, title))
      end

      def selected(window) = window.list_widget.selected_item

      # Runs the block with the item picked in +window+, if any; :keep.
      def with_selected(window)
        item = selected(window)
        yield item if item
        :keep
      end

      def status_text = "#{catalog.shelves.size} shelves │ #{Time.now.strftime('%H:%M')}"

      # The logo, the line under it and the shelves, on a new desktop.
      def desktop
        mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
        Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
        desktop_label('─── the file area of Teletype Games ───', :text_dim, 1, rows - 2, cols, align: :center)
        statusbar.right_text = status_text
        shelf_list
      end

      private

      def read_shelf(shelf, fresh: false)
        with_loading("Reading the #{shelf.name} shelf…") { catalog.titles(shelf, fresh: fresh) }
      end

      def transfer(session, title, protocol, data)
        text = BBS::FrameBuffer.wrap_ansi(Transfer.start(protocol, title), cols - 4)
        session.write("\r\n#{text.map { |l| "  #{l}\r\n" }.join}\r\n")
        Transfer.send_file(session, protocol, title, data)
      end

      def tell(text) = BBS::Dialogs.message(self, text, title: ' Download ', width: 64)

      def desktop_label(text, style, x, y, width, align: :left)
        label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
        label.layout(x, y, width, 1)
        add(label)
      end
    end
  end
end
