# frozen_string_literal: true

module UI
  module Windows
    module_function

    def online_users(app, services:)
      width = 50
      height = [services[:online].user_list.size + 6, 10].max
      window = BBS::Dialogs.centred_window(app, width: width, height: height,
                                          title: ' Online Users ')

      users = services[:online].user_list
      lines = users.map do |u|
        u == app.context[:username] ? "  #{u}  ← you" : "  #{u}"
      end
      lines = ['  (no one else here yet)'] if lines.empty?
      view = BBS::Widgets::ScrollView.new(lines: lines)
      view.layout(window.bounds.x + 2, window.bounds.y + 1,
                  width - 4, height - 4)
      window.add(view)

      ok = BBS::Widgets::Button.new(label: '&Close',
                                    on_click: ->(_) { app.close_window(window) })
      ok.layout(window.bounds.x + (width - 10) / 2, window.bounds.y + height - 2, 10, 1)
      window.add(ok)
      window.reset_focus
      app.open_window(window)
      window
    end

    def last_callers(app, services:)
      width = 64
      callers = services[:last_callers].recent(15)
      height = [callers.size + 6, 10].max
      window = BBS::Dialogs.centred_window(app, width: width, height: height,
                                          title: ' Last Callers ')

      lines = if callers.empty?
                ['  (no callers recorded yet)']
              else
                callers.map do |c|
                  ts = c.timestamp.to_s[0, 19].sub('T', ' ')
                  "  \e[2;37m#{ts}\e[0m  \e[1;33m#{c.username}\e[0m"
                end
              end
      view = BBS::Widgets::ScrollView.new(lines: lines)
      view.layout(window.bounds.x + 2, window.bounds.y + 1,
                  width - 4, height - 4)
      window.add(view)

      ok = BBS::Widgets::Button.new(label: '&Close',
                                    on_click: ->(_) { app.close_window(window) })
      ok.layout(window.bounds.x + (width - 10) / 2, window.bounds.y + height - 2, 10, 1)
      window.add(ok)
      window.reset_focus
      app.open_window(window)
      window
    end
  end
end
