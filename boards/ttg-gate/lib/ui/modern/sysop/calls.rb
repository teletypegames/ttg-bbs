# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The calls on the gate now, the earliest first, a row each like the
      # gate's own boards: who (a guest, or the account), from where, for
      # how long; under the list the chosen call's way in, face and place.
      # Redrawn every two seconds; RETURN or H hangs the chosen call up (not
      # the sysop's own).
      class Calls < View
        every(2) { redraw }

        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, [calls.size - 1, 0].max) }
        key(:enter, 'h', 'H') { guarded { hang_up(calls[@index]) } }

        def initialize(accounts)
          super
          @index = 0
        end

        private

        def tab = :calls

        def calls = BBS.calls

        def body
          list = calls
          @index = @index.clamp(0, [list.size - 1, 0].max)
          rows = list.empty? ? ["#{DIM}Nobody is on.#{RESET}"] : window(list, @index, per_page) { |call, lit| row(call, lit) }
          [crumbs('CALLS', "#{list.size} on the gate"), *rows, '', rule, *detail(list[@index]),
           *(@notice ? ['', @notice] : [])]
        end

        def row(call, lit)
          bg = lit ? SELECTED : ''
          "#{lit ? "#{bg}#{look.accent}▸" : ' '}#{bg} #{call.caller_name ? BOLD : DIM}#{fit(who(call), 24)}#{RESET}#{bg}  " \
            "#{TEXT}#{fit(call.caller_ip.to_s, 18)}  #{DIM}#{fit(BBS.duration(call.started_at).to_s, 8)}" \
            "#{fit(call.place.to_s, [width - 56, 0].max)}#{RESET}"
        end

        def who(call)
          name = call.caller_name || 'guest'
          call.session_id == session.session_id ? "#{name} (you)" : name
        end

        def detail(call)
          return [] unless call

          [fact('Via', call.call_via.to_s), fact('Face', call.face.to_s), fact('Where', call.place.to_s)]
        end

        def hints = '↑↓ choose   RETURN or H hang up   TAB next tab   Q back'

        def hang_up(call)
          return unless call
          return (@notice = "#{DIM}That is your own call.#{RESET}") if call.session_id == session.session_id

          who = call.caller_name || 'a guest'
          return unless yes?("Hang up #{who} (#{call.caller_ip})?")

          UI::Sysop.hang_up(call, by: sysop)
          @notice = "#{look.accent}#{plain(who)} hung up.#{RESET}"
        end
      end
    end
  end
end
