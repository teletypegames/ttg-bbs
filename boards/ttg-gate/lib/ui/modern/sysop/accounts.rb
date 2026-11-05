# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The accounts of the network by name: a ✖ for a banned one, the
      # roles, the last login. / searches names and roles (+blogger+ lists
      # the bloggers), RETURN opens the account, Q goes back.
      class Accounts < View
        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, last) }
        key(:left, :page_up) { @index = [@index - per_page, 0].max }
        key(:right, :page_down) { @index = (@index + per_page).clamp(0, last) }
        key(:enter) { guarded { open } }
        key('/') { guarded { search } }
        key(:escape, 'q', 'Q') { back }

        def initialize(accounts)
          super
          @index = 0
          @query = nil
          load
        end

        # Back from an account: its roles or ban may have changed.
        def resume = load

        private

        def load
          name   = @list&.dig(@index)&.name
          @list  = @accounts.accounts(@query)
          @index = (name && @list.index { |e| e.name == name }) || @index.clamp(0, last)
        end

        def last = [@list.size - 1, 0].max

        def body
          right = "#{@list.size} account#{'s' unless @list.size == 1}#{"  ·  “#{@query}”" if @query}"
          rows  = @list.empty? ? ['', "#{TEXT}No account here.#{RESET}"] : window(@list, @index, per_page) { |e, l| row(e, l) }
          [header('ACCOUNTS', right), rule, heading, *rows]
        end

        def heading = "#{DIM}    #{fit('NAME', 22)} #{fit('ROLES', roles_width)} LAST LOGIN#{RESET}"

        def roles_width = [width - (4 + 23 + 17), 10].max

        def row(entry, lit)
          ban = entry.banned? ? "#{RED}✖#{RESET}" : ' '
          "#{lit ? "#{SELECTED}#{GREEN}▸" : ' '}#{ban}#{SELECTED if lit}  #{BOLD}#{fit(entry.name, 22)}#{RESET}" \
            "#{SELECTED if lit} #{TEXT}#{fit(entry.roles.join(' '), roles_width)} " \
            "#{DIM}#{fit(when_text(entry.last_seen_at), 16)}#{RESET}"
        end

        def hints = '↑↓ choose   ←→ page   RETURN open   / search names and roles   Q back'

        def open
          entry = @list[@index] or return

          push(Account.new(@accounts, entry.name))
        end

        def search
          text = read_line('Search:', text: @query.to_s, max: 40, hint: 'A part of a name, or a role: sysop blogger …')
          return if text.nil?

          @query = text.strip.empty? ? nil : text.strip
          @index = 0
          load
        end
      end
    end
  end
end
