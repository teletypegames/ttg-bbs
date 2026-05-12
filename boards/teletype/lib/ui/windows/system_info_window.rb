# frozen_string_literal: true

module UI
  module Windows
    module_function

    def system_info(app, services:)
      width   = 60
      height  = 14
      window  = BBS::Dialogs.centred_window(app, width: width, height: height,
                                            title: ' System Info ')
      x, y    = window.bounds.x + 2, window.bounds.y + 1
      rows = [
        ['Online users',  services[:online].count.to_s],
        ['Messages',      services[:boards].total_count.to_s],
        ['Boards',        services[:boards].boards.size.to_s],
        ['Wiki',          'https://wiki.teletypegames.org'],
        ['Games API',     'https://teletypegames.org'],
        ['Platform',      RUBY_PLATFORM],
        ['Ruby',          RUBY_VERSION],
        ['Uptime',        format_uptime(services[:uptime])],
      ]

      rows.each_with_index do |(k, v), i|
        label = BBS::Widgets::Label.new(text: k.ljust(15), style_key: :input_label)
        label.layout(x, y + i, 16, 1)
        value = BBS::Widgets::Label.new(text: v.to_s, style_key: :window_text)
        value.layout(x + 16, y + i, width - 20, 1)
        window.add(label)
        window.add(value)
      end

      ok = BBS::Widgets::Button.new(label: '&Close',
                                    on_click: ->(_) { app.close_window(window) })
      ok.layout(window.bounds.x + (width - 10) / 2, window.bounds.y + height - 2, 10, 1)
      window.add(ok)
      window.reset_focus
      app.open_window(window)
      window
    end

    def format_uptime(start)
      return '–' unless start
      seconds = (Time.now - start).to_i
      h = seconds / 3600
      m = (seconds % 3600) / 60
      s = seconds % 60
      "#{h}h #{m}m #{s}s"
    end
  end
end
