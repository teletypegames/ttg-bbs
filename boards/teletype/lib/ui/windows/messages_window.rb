# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Two-pane message reader: left=board list, right=messages of the selected
    # board.  Press "n" or click [+ New] to compose, "r" to refresh.
    def messages(app, services:)
      cols  = app.cols
      rows  = app.rows
      w     = cols - 4
      h     = rows - 6
      window = BBS::Window.new(title: ' Message Boards ')
      window.layout(3, 3, w, h)
      window.theme = app.theme

      boards = services[:boards].boards
      board_list = BBS::Widgets::ListBox.new(
        items: boards,
        label: ->(b) { "  #{b.title}".ljust(18) }
      )
      board_list.layout(window.bounds.x + 2, window.bounds.y + 2, 20, h - 5)
      window.add(board_list)

      msg_lines = BBS::Widgets::ScrollView.new(lines: [])
      msg_lines.layout(window.bounds.x + 23, window.bounds.y + 2, w - 26, h - 5)
      window.add(msg_lines)

      reload = lambda do
        board = board_list.selected_item
        next unless board
        msgs = services[:boards].messages(board.id, 100)
        wrap_width = msg_lines.bounds.width - 1
        lines = []
        if msgs.empty?
          lines << "  (no messages on #{board.title} yet — press 'n' to start one)"
        else
          msgs.each do |m|
            head = "\e[2;37m#{m.timestamp}\e[0m  \e[1;33m#{m.username}\e[0m: "
            body = m.text.to_s
            wrap_text(head + body, wrap_width).each { |l| lines << l }
            lines << ''
          end
        end
        msg_lines.lines  = lines
        msg_lines.scroll = [lines.size - msg_lines.bounds.height, 0].max
      end

      board_list.on_select = ->(_, _) { reload.call }

      compose = BBS::Widgets::Button.new(
        label: '&New',
        on_click: ->(_) { compose_message(app, services: services, board: board_list.selected_item, on_posted: reload) }
      )
      compose.layout(window.bounds.x + 2, window.bounds.y + h - 2, 9, 1)
      window.add(compose)

      refresh = BBS::Widgets::Button.new(
        label: '&Refresh',
        on_click: ->(_) { reload.call }
      )
      refresh.layout(window.bounds.x + 13, window.bounds.y + h - 2, 13, 1)
      window.add(refresh)

      close = BBS::Widgets::Button.new(
        label: '&Close',
        on_click: ->(_) { app.close_window(window) }
      )
      close.layout(window.bounds.x + w - 11, window.bounds.y + h - 2, 9, 1)
      window.add(close)

      reload.call
      window.reset_focus
      window.focus_manager.focus(board_list)
      app.open_window(window)
      window
    end

    def compose_message(app, services:, board:, on_posted: nil)
      return BBS::Dialogs.message(app, 'Select a board first.', title: ' Compose ') unless board

      w = [app.cols - 8, 70].min
      h = 14
      window = BBS::Dialogs.centred_window(app, width: w, height: h,
                                          title: " Post to #{board.title} ")

      hint = BBS::Widgets::Label.new(
        text: "From: #{app.context[:username] || 'Anonymous'} — Ctrl-Enter sends",
        style_key: :input_label
      )
      hint.layout(window.bounds.x + 2, window.bounds.y + 1, w - 4, 1)
      window.add(hint)

      area = BBS::Widgets::TextArea.new(max_length: 1000)
      area.layout(window.bounds.x + 2, window.bounds.y + 3, w - 4, h - 6)
      window.add(area)

      status = BBS::Widgets::Label.new(text: '', style_key: :error)
      status.layout(window.bounds.x + 2, window.bounds.y + h - 3, w - 4, 1)
      window.add(status)

      send_btn = BBS::Widgets::Button.new(
        label: '&Send',
        on_click: lambda do |_|
          result = services[:boards].post(board.id, app.context[:username] || 'Anonymous', area.value)
          if result == :empty
            status.text = 'Message cannot be empty.'
          else
            app.close_window(window)
            on_posted&.call
          end
        end
      )
      send_btn.layout(window.bounds.x + w - 22, window.bounds.y + h - 2, 9, 1)
      window.add(send_btn)

      cancel = BBS::Widgets::Button.new(
        label: '&Cancel',
        on_click: ->(_) { app.close_window(window) }
      )
      cancel.layout(window.bounds.x + w - 12, window.bounds.y + h - 2, 10, 1)
      window.add(cancel)

      window.reset_focus
      window.focus_manager.focus(area)
      app.open_window(window)
      window
    end

    def wrap_text(text, width)
      return [''] if width <= 1
      # Treat the text as containing ANSI; wrap on visible width approximately
      # by splitting on whitespace.
      visible = text.gsub(/\e\[[\d;]*m/, '')
      return [text] if visible.length <= width
      lines = []
      cur = +''
      cur_visible = +''
      text.scan(/(\e\[[\d;]*m|\S+\s*|\s+)/) do |(token)|
        if token.start_with?("\e")
          cur << token
          next
        end
        visible_tok = token
        if cur_visible.length + visible_tok.length > width && !cur_visible.empty?
          lines << cur
          cur = +''
          cur_visible = +''
        end
        cur << token
        cur_visible << token
      end
      lines << cur unless cur.empty?
      lines
    end
  end
end
