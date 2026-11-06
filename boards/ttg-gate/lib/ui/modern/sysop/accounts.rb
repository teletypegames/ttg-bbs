# frozen_string_literal: true

module UI
  module Modern
    module Sysop
      # The accounts of the network by name, a row each (a ✖ for a banned
      # one, the roles, the last login), and under the list the chosen
      # account: its roles, dates, calls on the gate and ban. G grants a
      # role, R revokes one, B bans it (and hangs up its calls on the gate)
      # or lifts the ban, N gives it a new password, H hangs up its calls, /
      # finds names and roles (+blogger+ lists the bloggers). A sysop cannot
      # ban themselves or take their own sysop role.
      class Accounts < View
        key(:up) { @index = [@index - 1, 0].max }
        key(:down) { @index = (@index + 1).clamp(0, last) }
        key(:page_up) { @index = [@index - per_page, 0].max }
        key(:page_down) { @index = (@index + per_page).clamp(0, last) }
        key('/') { guarded { search } }
        key('g', 'G') { guarded { act(:grant) } }
        key('r', 'R') { guarded { act(:revoke) } }
        key('b', 'B') { guarded { act(:ban_or_unban) } }
        key('n', 'N') { guarded { act(:new_password) } }
        key('h', 'H') { guarded { act(:hang_up) } }

        def initialize(accounts)
          super
          @index = 0
          @query = nil
        end

        private

        def tab = :accounts

        def list = @accounts.accounts(@query)

        def last = [list.size - 1, 0].max

        def body
          entries = list
          @index  = @index.clamp(0, [entries.size - 1, 0].max)
          rows = entries.empty? ? ["#{TEXT}No account here.#{RESET}"] : window(entries, @index, per_page) { |e, lit| row(e, lit) }
          [crumbs('ACCOUNTS', counts(entries)), *rows, '', rule, *detail(entries[@index]),
           *(@notice ? ['', @notice] : [])]
        end

        def counts(entries) = "#{entries.size} account#{'s' unless entries.size == 1}#{"  ·  “#{@query}”" if @query}"

        def roles_width = [width - (4 + 23 + 17), 10].max

        def row(entry, lit)
          bg  = lit ? SELECTED : ''
          ban = entry.banned? ? "#{RED}✖#{RESET}" : ' '
          "#{lit ? "#{bg}#{look.accent}▸" : ' '}#{ban}#{bg}  #{BOLD}#{fit(entry.name, 22)}#{RESET}" \
            "#{bg} #{TEXT}#{fit(entry.roles.join(' '), roles_width)} #{DIM}#{fit(when_text(entry.last_seen_at), 16)}#{RESET}"
        end

        def detail(entry)
          return [] unless entry

          [fact('Roles', entry.roles.empty? ? '—' : entry.roles.join(', ')), fact('Made', when_text(entry.created_at)),
           fact('On the gate', calls_line(entry.name)), *ban_lines(entry)]
        end

        def calls_line(name)
          calls = UI::Sysop.calls_of(name)
          calls.empty? ? 'no call now' : calls.map { |c| "#{c.caller_ip} #{c.place}".strip }.join(' · ')
        end

        def ban_lines(entry)
          return [] unless entry.banned?

          reason = entry.ban_reason.to_s.empty? ? '' : " — #{entry.ban_reason}"
          ["#{RED}#{BOLD}BANNED#{RESET} #{TEXT}#{plain("#{when_text(entry.banned_at)} by #{entry.banned_by}#{reason}")}#{RESET}"]
        end

        def hints = '↑↓ choose   G grant  R revoke  B ban/lift  N new password  H hang up   / find   TAB next   Q back'

        # Runs +step+ on the chosen account.
        def act(step)
          @entry = list[@index] or return

          @notice = nil
          send(step)
        end

        def name = @entry.name

        def own? = UI::Sysop.own?(name, sysop)

        def say(text, color = look.accent) = @notice = "#{color}#{plain(text)}#{RESET}"

        def roles_hint = "Roles: #{TTG::Auth::ROLES.keys.join(' ')}"

        def grant
          role = read_line('Grant role:', max: 30, hint: roles_hint)&.strip&.downcase
          return if role.nil? || role.empty?
          return say("#{role} is not a role of the network.", RED) unless TTG::Auth::ROLES.key?(role)

          @accounts.grant(name, role, by: sysop)
          say("#{name}: #{role} granted.")
        end

        def revoke
          role = read_line('Revoke role:', max: 30, hint: "Has: #{@entry.roles.join(' ')}")&.strip&.downcase
          return if role.nil? || role.empty?
          return say('Your own sysop role stays.', RED) if own? && role == UI::Sysop::ROLE
          return say("#{name} has no #{role} role.", DIM) unless @entry.roles.include?(role)

          @accounts.revoke(name, role)
          say("#{name}: #{role} revoked.")
        end

        def ban_or_unban
          return say('You cannot ban yourself.', RED) if own?
          return unban if @entry.banned?

          reason = read_line('Ban reason:', max: 200, hint: 'Why, for the other sysops (RETURN: none, Esc: no ban)')
          return if reason.nil? || !yes?("Ban #{name}? Its calls on the gate are hung up.")

          hung = UI::Sysop.ban(@accounts, name, by: sysop, reason: reason)
          say("#{name} banned#{", #{hung} call(s) hung up" if hung.positive?}.")
        end

        def unban
          return unless yes?("Lift the ban of #{name}?")

          @accounts.unban(name, by: sysop)
          say("The ban of #{name} is lifted.")
        end

        def new_password
          return unless yes?("A new password for #{name}? The old one stops working.")

          password = UI::Sysop.new_password(@accounts, name, by: sysop)
          tell("The new password of #{name}:", '', password, '', 'Tell it to them; they change it in their profile (P).')
        end

        def hang_up
          return say('That is you.', DIM) if own?
          return say("No call of #{name} on the gate.", DIM) if UI::Sysop.calls_of(name).empty?
          return unless yes?("Hang up the calls of #{name}?")

          say("#{UI::Sysop.hang_up_calls(name, by: sysop)} call(s) hung up.")
        end

        def search
          text = read_line('Search:', text: @query.to_s, max: 40, hint: 'A part of a name, or a role: sysop blogger …')
          return if text.nil?

          @query = text.strip.empty? ? nil : text.strip
          @index = 0
        end
      end
    end
  end
end
