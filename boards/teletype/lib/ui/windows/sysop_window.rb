# frozen_string_literal: true

module UI
  module Windows
    module_function

    def sysop_console(app, services:)
      width = 70
      height = 18
      window = BBS::Dialogs.centred_window(app, width: width, height: height,
                                          title: ' Sysop Console ')

      lines = []
      lines << "  Sysop: \e[1;33m#{app.context[:username]}\e[0m"
      lines << ''
      lines << '  Stats'
      lines << "  · Online users:  #{services[:online].count}"
      lines << "  · Total messages: #{services[:boards].total_count}"
      lines << "  · Chat subscribers: #{services[:chat].subscriber_count}"
      lines << ''
      lines << '  Online users:'
      services[:online].user_list.each { |u| lines << "  · #{u}" }
      lines << ''
      lines << '  Last 5 callers:'
      services[:last_callers].recent(5).each do |c|
        lines << "  · #{c.username}  #{c.timestamp[0, 16].sub('T', ' ')}"
      end

      view = BBS::Widgets::ScrollView.new(lines: lines)
      view.layout(window.bounds.x + 2, window.bounds.y + 1,
                  width - 4, height - 4)
      window.add(view)

      broadcast = BBS::Widgets::Button.new(
        label: '&Broadcast',
        on_click: lambda do |_|
          BBS::Dialogs.input(app, prompt: 'Sysop broadcast message:',
                             title: ' Broadcast ', width: 64,
                             on_submit: lambda do |text|
                               next if text.strip.empty?
                               services[:chat].broadcast("[SYSOP] #{app.context[:username]}", text.strip)
                             end)
        end
      )
      broadcast.layout(window.bounds.x + 2, window.bounds.y + height - 2, 14, 1)
      window.add(broadcast)

      close = BBS::Widgets::Button.new(label: '&Close',
                                       on_click: ->(_) { app.close_window(window) })
      close.layout(window.bounds.x + width - 11, window.bounds.y + height - 2, 9, 1)
      window.add(close)

      window.reset_focus
      app.open_window(window)
      window
    end
  end
end
