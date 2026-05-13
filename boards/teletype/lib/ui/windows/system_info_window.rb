# frozen_string_literal: true

module UI
  module Windows
    class SystemInfo
      def self.open(app, services:)
        rows = [
          ['Online users', services[:online].count.to_s],
          ['Messages',     services[:boards].total_count.to_s],
          ['Boards',       services[:boards].boards.size.to_s],
          ['Wiki',         'https://wiki.teletypegames.org'],
          ['Games API',    'https://teletypegames.org'],
          ['Platform',     RUBY_PLATFORM],
          ['Ruby',         RUBY_VERSION],
          ['Uptime',       format_uptime(services[:uptime])],
        ]
        BBS::Windows::Info.open(app,
          title: ' System Info ', width: 60, height: 14,
          body: [{ kv: rows, label_width: 15 }]
        )
      end

      def self.format_uptime(start)
        return '–' unless start
        seconds = (Time.now - start).to_i
        h = seconds / 3600
        m = (seconds % 3600) / 60
        s = seconds % 60
        "#{h}h #{m}m #{s}s"
      end
      private_class_method :format_uptime
    end
  end
end
