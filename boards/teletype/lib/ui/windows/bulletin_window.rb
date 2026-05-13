# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Login splash: ASCII banner + last callers + new message counts. Closed
    # with Enter / Esc / clicking the OK button.
    def bulletin(app, services:)
      banner_lines = [
        "  \e[1;33m _____       _      _                  ____  ____  _____\e[0m",
        "  \e[1;33m|_   _|__   | |    | |_  __ _ _ _ ___  | __ )| __ )/ ____|\e[0m",
        "  \e[1;33m  | |/ _ \\  | |    | __|/ _` | '_/ _ \\ |  _ \\|  _ \\\\___ \\\e[0m",
        "  \e[1;33m  | |  __/  | |___ | |_| (_| | ||  __/ | |_) | |_) |___) |\e[0m",
        "  \e[1;33m  |_|\\___|  |_____|\\__|\\__,_|_| \\___| |____/|____/|____/\e[0m",
      ]
      caller_lines = services[:last_callers].recent(3).map do |c|
        "  · #{c.username}  \e[2;37m#{c.timestamp[0, 16].sub('T', ' ')}\e[0m"
      end
      BBS::Windows::Info.open(app,
        title: ' Welcome ', width: 70, height: 17,
        body: [
          *banner_lines.map { |l| { text: l, style: :accent } },
          :spacer,
          "Logged in as \e[1;33m#{app.context[:username] || 'Anonymous'}\e[0m",
          :spacer,
          "Online now:     #{services[:online].count}",
          "Total messages: #{services[:boards].total_count}",
          :spacer,
          'Last callers:',
          *caller_lines,
        ],
        buttons: [{ label: '&Continue', primary: true, cancel: true }]
      )
    end
  end
end
