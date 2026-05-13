# frozen_string_literal: true

module UI
  module Windows
    # Two-pane message reader: left=board list, right=messages of the selected
    # board. Press &New to compose, &Refresh to reload.
    class Messages
      def self.open(app, services:)
        BBS::Windows::MasterDetail.open(app,
          title:         ' Message Boards ',
          items:         services[:boards].boards,
          item_label:    ->(b) { b.title },
          list_width:    20,
          empty_message: '  (no boards configured)',
          render_detail: ->(board, width) { board_lines(services, board, width) },
          actions: [
            { label: '&New',     align: :left, on_click: ->(window) {
                board = window.list_widget.selected_item
                ComposeMessage.open(app, services: services, board: board,
                                    on_posted: -> { window.reload_detail })
                :keep
              } },
            { label: '&Refresh', align: :left, on_click: ->(window) {
                window.reload_detail
                :keep
              } }
          ]
        )
      end

      def self.board_lines(services, board, width)
        msgs = services[:boards].messages(board.id, 100)
        return ["  (no messages on #{board.title} yet — press 'n' to start one)"] if msgs.empty?
        lines = []
        msgs.each do |m|
          head = "\e[2;37m#{m.timestamp}\e[0m  \e[1;33m#{m.username}\e[0m: "
          BBS::FrameBuffer.wrap_ansi(head + m.text.to_s, width - 1).each { |l| lines << l }
          lines << ''
        end
        lines
      end
      private_class_method :board_lines
    end

    class ComposeMessage
      def self.open(app, services:, board:, on_posted: nil)
        return BBS::Dialogs.message(app, 'Select a board first.', title: ' Compose ') unless board

        username = app.context[:username] || 'Anonymous'
        width    = [app.cols - 8, 70].min
        BBS::Windows::Form.open(app,
          title:        " Post to #{board.title} ",
          width:        width, height: 14,
          hint:         "From: #{username} — Ctrl-Enter sends",
          submit_label: '&Send',
          cancel_label: '&Cancel',
          fields: [
            { key: :body, type: :textarea, value: '', max_length: 1000 }
          ],
          on_submit: ->(values, form) {
            result = services[:boards].post(board.id, username, values[:body])
            if result == :empty
              form.error('Message cannot be empty.')
              :keep
            else
              on_posted&.call
              :close
            end
          }
        )
      end
    end
  end
end
