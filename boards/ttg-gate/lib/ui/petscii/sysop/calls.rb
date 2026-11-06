# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The calls on the gate, the earliest first: a row each (its number,
      # who, how long), and under a rule the lit call's address, way in,
      # face and place. Redrawn every two seconds; RETURN or H hangs it up.
      class CallsView < Views::Picker
        include Shared

        PER_PAGE = 10
        HINT = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Hang up  ', false], ['←', true], [' Back', false]].freeze

        every(2) { redraw }

        key('h', 'H') { guarded { hang_up(selected) } }

        def initialize(_accounts)
          super(Rubbs.calls, per_page: PER_PAGE)
        end

        def section = :calls

        def hint = HINT

        def take(call) = guarded { hang_up(call) }

        def draw(canvas)
          reload_items(Rubbs.calls)
          Layout.band(canvas, 'CALLS', [items.size, page_mark].reject { |s| s.to_s.empty? }.join('  '), Canvas::YELLOW)
          on_page.each_with_index do |call, slot|
            list_row(
              canvas,
              Layout.row(1 + slot),
              slot,
              who(call),
              Rubbs.duration(call.started_at).to_s,
              name_color: call.caller_name ? Canvas::WHITE : Canvas::GREY
            )
          end
          detail(canvas, selected)
        end

        private

        def who(call)
          name = call.caller_name || 'guest'
          call.session_id == session.session_id ? "#{name} (you)" : name
        end

        def detail(canvas, call)
          top = Layout.row(1 + PER_PAGE)
          return facts(canvas, top, [['', 'Nobody is on.', Canvas::GREY]]) unless call

          facts(canvas, top, [['From', call.caller_ip], ['Via', call.call_via], ['Face', call.face], ['Where', call.place]])
        end

        def hang_up(call)
          return unless call
          return tell('That is your own call.') if call.session_id == session.session_id

          who = call.caller_name || 'a guest'
          return unless yes?("Hang up #{who}?", call.caller_ip.to_s)

          UI::Sysop.hang_up(call, by: sysop)
        end
      end
    end
  end
end
