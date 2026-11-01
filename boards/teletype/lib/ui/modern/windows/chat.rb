# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Live Chat: everyone on the lines, C64 callers too.
      module Chat
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title       Icon.title(:messages, 'Live Chat')
          w.placeholder 'Type a message and press Enter…'
          w.initial_lines do |ctx|
            ctx[:chat].drain(ctx[:session_id])
            ctx[:chat].history.map { |line| Formatters::Chat.line(line) }
          end
          w.on_submit { |text, _app, ctx| say(text, ctx) }
          w.on_poll { |app, ctx| ctx[:chat].drain(app.session_id).map { |line| Formatters::Chat.line(line) } }
        end

        # A line too soon after the last ones is dropped, as it always was.
        def self.say(text, ctx)
          ctx[:chat].say(ctx[:username] || AccountService::ANONYMOUS, text, caller_key: ctx[:caller_key])
          nil
        end
      end

      # The IRC channel, read only: the input line only tells how to join.
      module Irc
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title       { |ctx| Formatters::Irc.title(ctx[:irc]) }
          w.placeholder Formatters::Irc::PLACEHOLDER
          w.initial_lines do |ctx|
            ctx[:irc].subscribe(ctx[:session_id])
            Formatters::Irc.intro(ctx[:irc]) + ctx[:irc].history.map { |line| Formatters::Irc.line(line) }
          end
          w.on_submit do |_text, _app, ctx|
            ctx[:irc_hint] = true
            nil
          end
          w.on_poll { |app, ctx| poll(app, ctx) }
        end

        def self.poll(app, ctx)
          hint = ctx.delete(:irc_hint) ? Formatters::Irc.how_to_join(ctx[:irc]) : []
          ctx[:irc].drain(app.session_id).map { |line| Formatters::Irc.line(line) } + hint
        end
      end

      # Help > Ask the TTG Master.
      module Master
        GREETING = 'Hey, caller! I am the sysop of this board. Ask me where things are, what is new, what is coming up.'

        def self.configure(w)
          w.accent Accent::STYLES[:help]
          w.maximizable true
          w.title       Icon.title(:help, 'Ask the TTG Master')
          w.placeholder 'Ask about the board and press Enter…'
          w.initial_lines do |ctx|
            ctx[:master_queue] = Queue.new
            ctx[:app].ask_master(ctx, ctx[:question]) if ctx[:question]
            Formatters::Master.lines('TTG Master', GREETING, ctx[:app].cols)
          end
          w.on_submit { |text, app, ctx| app.ask_master(ctx, text.strip) }
          w.on_poll { |_app, ctx| drain(ctx[:master_queue]) }
        end

        def self.drain(queue)
          lines = []
          lines << queue.pop until queue.empty?
          lines
        end
      end
    end
  end
end
