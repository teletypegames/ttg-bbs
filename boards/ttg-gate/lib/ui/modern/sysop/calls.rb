# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The calls on the gate now, the earliest first: who (a guest, or the
      # account), from where, through what, which face, how long, and where
      # (› a board while the gate carries them there). Redrawn every two
      # seconds; RETURN or H hangs the chosen call up (not the sysop's own).
      class Calls < View
        every(2) { redraw }

        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, [calls.size - 1, 0].max) }
        key(:enter, 'h', 'H') { guarded { hang_up(calls[@index]) } }
        key(:escape, 'q', 'Q') { back }

        def initialize(accounts)
          super
          @index = 0
        end

        private

        def calls = BBS.calls

        def body
          list = calls
          @index = @index.clamp(0, [list.size - 1, 0].max)
          [header('CALLS', "#{list.size} on the gate"), rule, heading,
           *window(list, @index, per_page) { |call, lit| row(call, lit) }, *(@notice ? ['', @notice] : [])]
        end

        def heading
          columns = [fit('WHO', 16), fit('FROM', 16), fit('VIA', 12), fit('FACE', 8), fit('FOR', 8), 'WHERE']
          "#{DIM}  #{columns.join(' ')}#{RESET}"
        end

        def row(call, lit)
          rest = width - (2 + 17 + 17 + 13 + 9 + 9)
          "#{lit ? "#{SELECTED}#{GREEN}▸ " : '  '}#{call.caller_name ? BOLD : DIM}#{fit(who(call), 16)}#{RESET}" \
            "#{SELECTED if lit} #{TEXT}#{fit(call.caller_ip.to_s, 16)} #{fit(call.call_via, 12)} " \
            "#{fit(call.face.to_s, 8)} #{fit(BBS.duration(call.started_at), 8)} " \
            "#{GREEN}#{fit(call.place.to_s, rest)}#{RESET}"
        end

        def who(call)
          name = call.caller_name || 'guest'
          call.session_id == session.session_id ? "#{name} (you)" : name
        end

        def hints = '↑↓ choose   RETURN or H hang up   Q back'

        def hang_up(call)
          return unless call
          return (@notice = "#{DIM}That is your own call.#{RESET}") if call.session_id == session.session_id

          who = call.caller_name || 'a guest'
          return unless yes?("Hang up #{who} (#{call.caller_ip})?")

          call.hang_up
          BBS.log('sysop', 'hung up', by: sysop, user: call.caller_name, ip: call.caller_ip.to_s)
          @notice = "#{GREEN}#{plain(who)} hung up.#{RESET}"
        end
      end
    end
  end
end
