# frozen_string_literal: true

module UI
  module Windows
    module_function

    def online_users(app, services:)
      users    = services[:online].user_list
      username = app.context[:username]
      body = if users.empty?
               ['  (no one else here yet)']
             else
               users.map { |u| u == username ? "  #{u}  ← you" : "  #{u}" }
             end
      BBS::Windows::Info.open(app,
        title: ' Online Users ',
        width: 50, height: [users.size + 6, 10].max,
        scroll: true, body: body
      )
    end

    def last_callers(app, services:)
      callers = services[:last_callers].recent(15)
      body = if callers.empty?
               ['  (no callers recorded yet)']
             else
               callers.map do |c|
                 ts = c.timestamp.to_s[0, 19].sub('T', ' ')
                 "  \e[2;37m#{ts}\e[0m  \e[1;33m#{c.username}\e[0m"
               end
             end
      BBS::Windows::Info.open(app,
        title: ' Last Callers ',
        width: 64, height: [callers.size + 6, 10].max,
        scroll: true, body: body
      )
    end
  end
end
