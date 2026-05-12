# frozen_string_literal: true

module UI
  module Windows
    module_function

    def chat(app, services:)
      cols = app.cols
      rows = app.rows
      w = cols - 8
      h = rows - 6
      window = BBS::Window.new(title: ' Live Chat ')
      window.layout(5, 3, w, h)
      window.theme = app.theme

      history = BBS::Widgets::ScrollView.new(lines: services[:chat].history.map { |l| format_line(l) })
      history.layout(window.bounds.x + 2, window.bounds.y + 1, w - 4, h - 5)
      window.add(history)
      history.scroll = [history.lines.size - history.bounds.height, 0].max

      input = BBS::Widgets::TextInput.new(placeholder: 'Type a message and press Enter…')
      input.layout(window.bounds.x + 2, window.bounds.y + h - 3, w - 14, 1)
      input.on_submit = lambda do |value, _|
        next if value.strip.empty?
        services[:chat].broadcast(app.context[:username] || 'Anonymous', value.strip)
        input.value = ''
        :handled
      end
      window.add(input)

      close = BBS::Widgets::Button.new(label: '&Close',
                                       on_click: ->(_) { app.close_window(window) })
      close.layout(window.bounds.x + w - 11, window.bounds.y + h - 3, 9, 1)
      window.add(close)

      # Stash a poll lambda on the window so the app tick can pull updates
      window.instance_variable_set(:@chat_poll, lambda do
        new_lines = services[:chat].drain(app.session_id).map { |l| format_line(l) }
        unless new_lines.empty?
          history.lines = (history.lines + new_lines).last(500)
          history.scroll = [history.lines.size - history.bounds.height, 0].max
        end
      end)

      window.reset_focus
      window.focus_manager.focus(input)
      app.open_window(window)
      window
    end

    def format_line(line)
      "  \e[2;37m#{line.timestamp}\e[0m  \e[1;33m#{line.username}\e[0m: #{line.text}"
    end
  end
end
