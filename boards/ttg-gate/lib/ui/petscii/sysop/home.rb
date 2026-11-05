# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The console's first screen: Calls, Accounts, Log, and a few numbers
      # under them. CRSR and RETURN or 1-3 open one.
      class Home < Views::Picker
        include Shared

        ITEMS = [
          [:calls,    'Calls',    'who is on the gate now'],
          [:accounts, 'Accounts', 'roles, bans, passwords'],
          [:log,      'Log',      "the gate's last lines"]
        ].freeze
        HINT = [['CRSR', true], [' Move  ', false], ['RETURN', true], [' Open  ', false], ['←', true], [' Back', false]].freeze

        def initialize(accounts)
          super(ITEMS, per_page: ITEMS.size)
          @accounts = accounts
        end

        def hint = HINT

        def take(item)
          guarded { push({ calls: Calls, accounts: Accounts, log: LogView }.fetch(item.first).new(@accounts)) }
        end

        def draw(canvas)
          Layout.band(canvas, 'CONSOLE', '', Canvas::YELLOW)
          ITEMS.each_with_index { |item, i| row(canvas, Layout.row(2 + (i * 2)), item, i) }
          stats = @accounts.statistics
          rule(canvas, Layout.row(9))
          lines = ["#{BBS.calls.size} on the gate", "#{stats[:accounts]} accounts",
                   "#{stats[:seen_day]} logged in today", "#{stats[:new_week]} new this week"]
          lines.each_with_index { |l, i| canvas.text(Layout.row(11 + i), 1, l, Canvas::LIGHT_GREY) }
        end

        private

        def row(canvas, row, item, slot)
          (_, label, note) = item
          if slot == @index
            canvas.text(row, 0, " #{slot + 1}  #{label.ljust(9)} #{note}".ljust(Layout::EDGE), Canvas::CYAN, rvs: true)
          else
            Layout.runs(canvas, row, 1, [[(slot + 1).to_s, Canvas::YELLOW], ["  #{label.ljust(9)} ", Canvas::WHITE],
                                         [note, Canvas::GREY]])
          end
        end
      end
    end
  end
end
