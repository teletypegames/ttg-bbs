# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # A line of input at the bottom of the screen: the search words.
      # RETURN takes it, Esc gives up (nil), BACKSPACE takes a letter back.
      class Prompt
        include Style

        MAX = 60

        def initialize(session)
          @session = session
        end

        def read(label, initial = '', hint: '')
          text = +initial.to_s
          loop do
            draw(label, text, hint)
            case (k = key)
            when :enter then return done(text.strip)
            when :escape then return done(nil)
            when :backspace then text.chop!
            when String then text << k if k.length == 1 && k.match?(/[[:print:]]/) && text.length < MAX
            end
          end
        end

        private

        def done(value)
          @session.write("\e[?25l")
          value
        end

        def draw(label, text, hint)
          row = rows - 1
          shown = text[-[width - label.length - 3, 1].max..] || text
          @session.write("\e[#{row - 1};1H#{RESET}#{pad}#{DIM}#{fit(hint, width)}#{RESET}\e[K" \
                         "\e[#{row};1H#{pad}#{GREEN}#{BOLD}#{label}#{RESET} #{TEXT}#{shown}#{RESET}\e[K\e[?25h")
        end
      end
    end
  end
end
