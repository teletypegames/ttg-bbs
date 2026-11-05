# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The console's first screen: its three parts and a line of numbers.
      # The arrows or 1-3 choose, RETURN opens, Q goes back to the gate.
      class Home < View
        ITEMS = [
          [:calls,    'Calls',    'who is on the gate now, where, how long; hang one up'],
          [:accounts, 'Accounts', 'the accounts of the network: roles, bans, a new password'],
          [:log,      'Log',      'the last lines the gate wrote, logins and bans among them']
        ].freeze

        key(:up) { @index = (@index - 1) % ITEMS.size }
        key(:down) { @index = (@index + 1) % ITEMS.size }
        key(:enter) { open_part(ITEMS[@index].first) }
        key(/\A[1-3]\z/) { |k| open_part(ITEMS[k.to_i - 1].first) }
        key(:escape, 'q', 'Q') { back }

        def initialize(accounts)
          super
          @index = 0
        end

        private

        def body
          stats = @accounts.statistics
          items = ITEMS.each_with_index.map do |(_, label, note), i|
            menu_row("#{i + 1}  #{label}", note, 14, lit: i == @index)
          end
          [header('CONSOLE', sysop), rule, '', *items, '', rule,
           "#{TEXT}#{BBS.calls.size} on the gate  ·  #{stats[:accounts]} accounts  ·  " \
           "#{stats[:seen_day]} logged in today  ·  #{stats[:new_week]} new this week#{RESET}"]
        end

        def hints = '↑↓ choose   RETURN or 1-3 open   Q back to the gate'

        def open_part(part)
          guarded do
            push({ calls: Calls, accounts: Accounts, log: LogView }.fetch(part).new(@accounts))
          end
        end
      end
    end
  end
end
