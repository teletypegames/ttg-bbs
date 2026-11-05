# frozen_string_literal: true

require 'securerandom'

module UI
  module Modern
    module Sysop
      # One account: its roles, when it was made and last logged in, its ban
      # and its calls on the gate. G grants a role, R revokes one, B bans
      # (and hangs up its calls on the gate) or lifts the ban, N gives it a
      # new password, H hangs up its calls. A sysop cannot ban themselves or
      # take their own sysop role.
      class Account < View
        key('g', 'G') { guarded { grant } }
        key('r', 'R') { guarded { revoke } }
        key('b', 'B') { guarded { ban_or_unban } }
        key('n', 'N') { guarded { new_password } }
        key('h', 'H') { guarded { hang_up } }
        key(:escape, 'q', 'Q') { back }

        def initialize(accounts, name)
          super(accounts)
          @name = name
        end

        private

        def entry = @accounts.entry(@name)

        def body
          e = entry or return [header('ACCOUNTS › ?'), rule, '', "#{RED}No such account.#{RESET}"]

          [header("ACCOUNTS › #{e.name}", "##{e.id}"), rule, '',
           fact('Roles', e.roles.empty? ? '—' : e.roles.join(', ')),
           fact('Made', when_text(e.created_at)),
           fact('Last login', when_text(e.last_seen_at)),
           fact('On the gate', calls_line(e.name)),
           *ban_lines(e), *(@notice ? ['', @notice] : [])]
        end

        def fact(label, value) = "#{DIM}#{label.ljust(13)}#{RESET}#{TEXT}#{plain(value)}#{RESET}"

        def calls_line(name)
          calls = Sysop.calls_of(name)
          calls.empty? ? 'no call now' : calls.map { |c| "#{c.caller_ip} #{c.place}".strip }.join(' · ')
        end

        def ban_lines(entry)
          return [] unless entry.banned?

          reason = entry.ban_reason.to_s.empty? ? '' : " — #{entry.ban_reason}"
          banned = plain("#{when_text(entry.banned_at)} by #{entry.banned_by}#{reason}")
          ['', "#{RED}#{BOLD}BANNED#{RESET} #{TEXT}#{banned}#{RESET}"]
        end

        def hints
          "G grant role   R revoke role   B #{entry&.banned? ? 'lift the ban' : 'ban'}   N new password   H hang up   Q back"
        end

        def own? = BBS::Auth::Names.key(@name) == BBS::Auth::Names.key(sysop)

        def roles_hint = "Roles: #{TTG::Auth::ROLES.keys.join(' ')}"

        def grant
          role = read_line('Grant role:', max: 30, hint: roles_hint)&.strip&.downcase
          return if role.nil? || role.empty?
          return (@notice = "#{RED}#{plain(role)} is not a role of the network.#{RESET}") unless TTG::Auth::ROLES.key?(role)

          @accounts.grant(@name, role, by: sysop)
          @notice = "#{GREEN}#{plain(role)} granted.#{RESET}"
        end

        def revoke
          role = read_line('Revoke role:', max: 30, hint: "Has: #{entry.roles.join(' ')}")&.strip&.downcase
          return if role.nil? || role.empty?
          return (@notice = "#{RED}Your own sysop role stays.#{RESET}") if own? && role == ROLE
          return (@notice = "#{DIM}It has no #{plain(role)} role.#{RESET}") unless entry.roles.include?(role)

          @accounts.revoke(@name, role)
          @notice = "#{GREEN}#{plain(role)} revoked.#{RESET}"
        end

        def ban_or_unban
          return (@notice = "#{RED}You cannot ban yourself.#{RESET}") if own?
          return unban if entry.banned?

          reason = read_line('Ban reason:', max: 200, hint: 'Why, for the other sysops (RETURN: none, Esc: no ban)')
          return if reason.nil? || !yes?("Ban #{@name}? Its calls on the gate are hung up.")

          @accounts.ban(@name, by: sysop, reason: reason)
          hung = hang_up_calls
          @notice = "#{GREEN}Banned#{", #{hung} call(s) hung up" if hung.positive?}.#{RESET}"
        end

        def unban
          return unless yes?("Lift the ban of #{@name}?")

          @accounts.unban(@name, by: sysop)
          @notice = "#{GREEN}The ban is lifted.#{RESET}"
        end

        def new_password
          return unless yes?("A new password for #{@name}? The old one stops working.")

          password = SecureRandom.alphanumeric(12)
          @accounts.set_password(@name, password)
          BBS.log('sysop', 'new password', by: sysop, user: @name)
          tell("The new password of #{@name}:", '', password, '', 'Tell it to them; they change it in their profile (P).')
        end

        def hang_up
          return (@notice = "#{DIM}That is you.#{RESET}") if own?
          return (@notice = "#{DIM}No call of #{plain(@name)} on the gate.#{RESET}") if Sysop.calls_of(@name).empty?
          return unless yes?("Hang up the calls of #{@name}?")

          @notice = "#{GREEN}#{hang_up_calls} call(s) hung up.#{RESET}"
        end

        def hang_up_calls
          calls = Sysop.calls_of(@name)
          calls.each do |call|
            call.hang_up
            BBS.log('sysop', 'hung up', by: sysop, user: call.caller_name, ip: call.caller_ip.to_s)
          end
          calls.size
        end
      end
    end
  end
end
