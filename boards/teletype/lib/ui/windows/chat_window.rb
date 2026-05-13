# frozen_string_literal: true

module UI
  module Windows
    class Chat
      def self.open(app, services:)
        username = app.context[:username] || 'Anonymous'
        BBS::Windows::Stream.open(app,
          title: ' Live Chat ',
          initial_lines: services[:chat].history.map { |l| format_chat_line(l) },
          placeholder: 'Type a message and press Enter…',
          on_submit: ->(text, _a) { services[:chat].broadcast(username, text.strip) },
          on_poll:   ->(a)         { services[:chat].drain(a.session_id).map { |l| format_chat_line(l) } }
        )
      end

      def self.format_chat_line(line)
        "  \e[2;37m#{line.timestamp}\e[0m  \e[1;33m#{line.username}\e[0m: #{line.text}"
      end
      private_class_method :format_chat_line
    end
  end
end
