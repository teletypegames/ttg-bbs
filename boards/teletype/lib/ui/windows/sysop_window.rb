# frozen_string_literal: true

module UI
  module Windows
    class SysopConsole
      def self.open(app, services:)
        body = []
        body << "  Sysop: \e[1;33m#{app.context[:username]}\e[0m"
        body << :spacer
        body << '  Stats'
        body << "  · Online users:  #{services[:online].count}"
        body << "  · Total messages: #{services[:boards].total_count}"
        body << "  · Chat subscribers: #{services[:chat].subscriber_count}"
        body << :spacer
        body << '  Online users:'
        services[:online].user_list.each { |u| body << "  · #{u}" }
        body << :spacer
        body << '  Last 5 callers:'
        services[:last_callers].recent(5).each do |c|
          body << "  · #{c.username}  #{c.timestamp[0, 16].sub('T', ' ')}"
        end

        BBS::Windows::Info.open(app,
          title: ' Sysop Console ', width: 70, height: 18, scroll: true,
          body: body,
          buttons: [
            { label: '&Broadcast', align: :left, on_click: ->(_window) {
                BBS::Dialogs.input(app, prompt: 'Sysop broadcast message:',
                                   title: ' Broadcast ', width: 64,
                                   on_submit: lambda do |text|
                                     next if text.strip.empty?
                                     services[:chat].broadcast("[SYSOP] #{app.context[:username]}", text.strip)
                                   end)
                :keep
              } },
            { label: '&Close', cancel: true }
          ]
        )
      end
    end
  end
end
