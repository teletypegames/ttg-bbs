# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The calls on the gate, the earliest first: a row each (who, how
      # long), and under a rule the lit call's address, way in, face and
      # place. Redrawn every two seconds; RETURN or H hangs it up.
      class Calls < Views::Picker
        include Shared

        PER_PAGE = 12
        HINT = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Hang up  ', false], ['←', true], [' Back', false]].freeze

        every(2) { redraw }

        key('h', 'H') { guarded { hang_up(selected) } }

        def initialize(accounts)
          super(BBS.calls, per_page: PER_PAGE)
          @accounts = accounts
          @notice   = nil
        end

        def hint = HINT

        def take(call) = guarded { hang_up(call) }

        def draw(canvas)
          reload_items(BBS.calls)
          Layout.band(canvas, 'CALLS', "#{items.size} on", Canvas::YELLOW)
          on_page.each_with_index { |call, slot| row(canvas, Layout.row(1 + slot), call, slot) }
          detail(canvas, selected)
          notice(canvas, Layout::ROWS - 1)
        end

        private

        def who(call)
          name = call.caller_name || 'guest'
          call.session_id == session.session_id ? "#{name} (you)" : name
        end

        def row(canvas, row, call, slot)
          name = Layout.plain(who(call))[0, 30].ljust(31)
          time = BBS.duration(call.started_at).to_s.rjust(7)
          if slot == @index
            canvas.text(row, 0, " #{name}#{time}".ljust(Layout::WIDTH), Canvas::CYAN, rvs: true)
          else
            Layout.runs(canvas, row, 1, [[name, call.caller_name ? Canvas::WHITE : Canvas::GREY], [time, Canvas::CYAN]])
          end
        end

        def detail(canvas, call)
          top = 2 + PER_PAGE
          Layout.rule(canvas, Layout.row(top))
          return canvas.text(Layout.row(top + 1), 1, 'Nobody else is on.', Canvas::GREY) unless call

          [['From', call.caller_ip.to_s], ['Via', call.call_via.to_s], ['Face', call.face.to_s],
           ['Where', call.place.to_s]].each_with_index do |(label, value), i|
            Layout.runs(canvas, Layout.row(top + 1 + i), 1, [[label.ljust(7), Canvas::GREY], [Layout.plain(value), Canvas::LIGHT_GREY]])
          end
        end

        def hang_up(call)
          return unless call
          return (@notice = ['That is your own call.', Canvas::GREY]) if call.session_id == session.session_id

          who = call.caller_name || 'a guest'
          return unless yes?("Hang up #{who}?", call.caller_ip.to_s)

          UI::Sysop.hang_up(call, by: sysop)
          @notice = ["#{who} hung up.", Canvas::LIGHT_GREEN]
        end
      end
    end
  end
end
