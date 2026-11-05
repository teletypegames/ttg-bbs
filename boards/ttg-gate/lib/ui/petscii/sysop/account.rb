# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # One account: its roles, when made and last logged in, its ban and
      # its calls on the gate. G grants a role, R revokes one, B bans or
      # lifts the ban, N gives it a new password, H hangs up its calls.
      class Account < Views::View
        include Shared

        HINT = [['G', true], ['rant ', false], ['R', true], ['evoke ', false], ['B', true], ['an ', false], ['N', true],
                ['ew pw ', false], ['H', true], ['ang up', false]].freeze

        key('g', 'G') { guarded { grant } }
        key('r', 'R') { guarded { revoke } }
        key('b', 'B') { guarded { ban_or_unban } }
        key('n', 'N') { guarded { new_password } }
        key('h', 'H') { guarded { hang_up } }

        def initialize(accounts, name)
          super()
          @accounts = accounts
          @name     = name
          @notice   = nil
        end

        def hint = HINT

        def draw(canvas)
          entry = @accounts.entry(@name)
          return Layout.band(canvas, 'NO SUCH ACCOUNT', '', Canvas::LIGHT_RED) unless entry

          Layout.band(canvas, Layout.plain(entry.name), "##{entry.id}", Canvas::YELLOW)
          facts(entry).each_with_index do |(label, value, color), i|
            Layout.runs(canvas, Layout.row(2 + i), 1, [[label.ljust(9), Canvas::GREY], [Layout.plain(value), color]])
          end
          notice(canvas, Layout::ROWS - 1)
        end

        private

        def facts(entry)
          calls = UI::Sysop.calls_of(entry.name)
          list = [['Roles', entry.roles.join(' '), Canvas::WHITE], ['Made', when_text(entry.created_at), Canvas::LIGHT_GREY],
                  ['Login', when_text(entry.last_seen_at), Canvas::LIGHT_GREY],
                  ['On now', calls.empty? ? 'no call' : "#{calls.size} call(s)", Canvas::LIGHT_GREY]]
          return list unless entry.banned?

          list + [['', '', nil], ['BANNED', when_text(entry.banned_at), Canvas::LIGHT_RED],
                  ['by', entry.banned_by.to_s, Canvas::LIGHT_GREY], ['why', entry.ban_reason.to_s[0, 30], Canvas::LIGHT_GREY]]
        end

        def entry = @accounts.entry(@name)

        def own? = UI::Sysop.own?(@name, sysop)

        def say(text, color = Canvas::LIGHT_GREEN) = @notice = [text, color]

        def grant
          role = read_line('Role:', max: 20)&.strip&.downcase
          return if role.nil? || role.empty?
          return say("#{role}: no such role", Canvas::LIGHT_RED) unless TTG::Auth::ROLES.key?(role)

          @accounts.grant(@name, role, by: sysop)
          say("#{role} granted.")
        end

        def revoke
          role = read_line('Role:', max: 20)&.strip&.downcase
          return if role.nil? || role.empty?
          return say('Your own sysop role stays.', Canvas::LIGHT_RED) if own? && role == UI::Sysop::ROLE
          return say("It has no #{role} role.", Canvas::GREY) unless entry.roles.include?(role)

          @accounts.revoke(@name, role)
          say("#{role} revoked.")
        end

        def ban_or_unban
          return say('You cannot ban yourself.', Canvas::LIGHT_RED) if own?
          return unban if entry.banned?

          reason = read_line('Why:', max: 30)
          return if reason.nil? || !yes?("Ban #{@name}?", 'Its calls on the gate', 'are hung up.')

          hung = UI::Sysop.ban(@accounts, @name, by: sysop, reason: reason)
          say("Banned#{", #{hung} call(s) hung up" if hung.positive?}.")
        end

        def unban
          return unless yes?("Lift the ban of #{@name}?")

          @accounts.unban(@name, by: sysop)
          say('The ban is lifted.')
        end

        def new_password
          return unless yes?("New password for #{@name}?", 'The old one stops working.')

          password = UI::Sysop.new_password(@accounts, @name, by: sysop)
          tell(
            ['The new password:', Canvas::WHITE],
            '',
            [password, Canvas::YELLOW],
            '',
            'Tell it to them; they change',
            'it in their profile.'
          )
        end

        def hang_up
          return say('That is you.', Canvas::GREY) if own?
          return say('No call on the gate.', Canvas::GREY) if UI::Sysop.calls_of(@name).empty?
          return unless yes?("Hang up #{@name}?")

          say("#{UI::Sysop.hang_up_calls(@name, by: sysop)} call(s) hung up.")
        end
      end
    end
  end
end
