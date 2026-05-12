# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Login splash: ASCII banner + last callers + new message counts. Closed
    # with Enter / Esc / clicking the OK button.
    def bulletin(app, services:)
      width  = 70
      height = 17
      window = BBS::Dialogs.centred_window(app, width: width, height: height,
                                          title: ' Welcome ')

      banner_lines = [
        "  \e[1;33m _____       _      _                  ____  ____  _____\e[0m",
        "  \e[1;33m|_   _|__   | |    | |_  __ _ _ _ ___  | __ )| __ )/ ____|\e[0m",
        "  \e[1;33m  | |/ _ \\  | |    | __|/ _` | '_/ _ \\ |  _ \\|  _ \\\\___ \\\e[0m",
        "  \e[1;33m  | |  __/  | |___ | |_| (_| | ||  __/ | |_) | |_) |___) |\e[0m",
        "  \e[1;33m  |_|\\___|  |_____|\\__|\\__,_|_| \\___| |____/|____/|____/\e[0m",
      ]
      banner_lines.each_with_index do |line, i|
        l = BBS::Widgets::Label.new(text: line, style_key: :accent)
        l.layout(window.bounds.x + 1, window.bounds.y + 1 + i, width - 2, 1)
        window.add(l)
      end

      summary = [
        "Logged in as \e[1;33m#{app.context[:username] || 'Anonymous'}\e[0m",
        '',
        "Online now:     #{services[:online].count}",
        "Total messages: #{services[:boards].total_count}",
        '',
        'Last callers:',
      ]
      services[:last_callers].recent(3).each do |c|
        summary << "  · #{c.username}  \e[2;37m#{c.timestamp[0, 16].sub('T', ' ')}\e[0m"
      end

      summary.each_with_index do |line, i|
        l = BBS::Widgets::Label.new(text: line, style_key: :window_text)
        l.layout(window.bounds.x + 2, window.bounds.y + 7 + i, width - 4, 1)
        window.add(l)
      end

      ok = BBS::Widgets::Button.new(label: '&Continue',
                                    on_click: ->(_) { app.close_window(window) })
      ok.layout(window.bounds.x + (width - 12) / 2, window.bounds.y + height - 2, 12, 1)
      window.add(ok)
      window.reset_focus
      app.open_window(window)
      window
    end
  end
end
