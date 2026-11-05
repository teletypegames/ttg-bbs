# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The accounts of the network by name: a row each (its number, a red
      # * for a banned one, the name, the roles as letters), and under a
      # rule the lit account's roles, dates, calls and ban. G grants a role,
      # R revokes one, B bans or lifts the ban, N gives a new password, H
      # hangs up its calls on the gate, / finds names and roles.
      class AccountsView < Views::Picker
        include Shared

        PER_PAGE = 10
        # The roles in a row, as letters.
        SHORT = { 'member' => 'M', 'sysop' => 'S', 'blogger' => 'B', 'wiki-supervisor' => 'W' }.freeze
        HINT = [['G', true], ['rant ', false], ['R', true], ['evoke ', false], ['B', true], ['an ', false], ['N', true],
                ['ew pw ', false], ['H', true], ['ang up ', false], ['/', true]].freeze

        key('g', 'G') { guarded { grant } }
        key('r', 'R') { guarded { revoke } }
        key('b', 'B') { guarded { ban_or_unban } }
        key('n', 'N') { guarded { new_password } }
        key('h', 'H') { guarded { hang_up } }
        key('/') { guarded { search } }

        def initialize(accounts)
          @accounts = accounts
          @query    = nil
          super(accounts.accounts, per_page: PER_PAGE)
        end

        def section = :accounts

        def hint = HINT

        def draw(canvas)
          reload_items(@accounts.accounts(@query))
          right = [@query, items.size, page_mark].reject { |s| s.to_s.empty? }.join('  ')
          Layout.band(canvas, 'ACCOUNTS', right, Canvas::YELLOW)
          return canvas.text(Layout.row(2), 1, 'No account here.', Canvas::GREY) if items.empty?

          on_page.each_with_index { |entry, slot| account_row(canvas, entry, slot) }
          facts(canvas, Layout.row(1 + PER_PAGE), facts_of(selected))
        end

        private

        def account_row(canvas, entry, slot)
          list_row(
            canvas,
            Layout.row(1 + slot),
            slot,
            entry.name,
            roles(entry),
            mark:       entry.banned? ? '*' : nil,
            name_color: entry.banned? ? Canvas::GREY : Canvas::WHITE
          )
        end

        def roles(entry) = entry.roles.map { |r| SHORT.fetch(r, r[0].upcase) }.join

        def facts_of(entry)
          calls = UI::Sysop.calls_of(entry.name)
          list = [['Roles', entry.roles.join(' '), Canvas::WHITE], ['Made', when_text(entry.created_at)],
                  ['Login', when_text(entry.last_seen_at)], ['On now', calls.empty? ? 'no call' : "#{calls.size} call(s)"]]
          return list unless entry.banned?

          list + [['BANNED', "#{when_text(entry.banned_at)} #{entry.banned_by}", Canvas::LIGHT_RED],
                  ['Why', entry.ban_reason.to_s[0, 30]]]
        end

        def name = selected&.name

        def own? = UI::Sysop.own?(name, sysop)

        def grant
          return unless name

          role = read_line('Role:', max: 20)&.strip&.downcase
          return if role.nil? || role.empty?
          return tell("#{role}: no such role.") unless TTG::Auth::ROLES.key?(role)

          @accounts.grant(name, role, by: sysop)
        end

        def revoke
          return unless name

          role = read_line('Role:', max: 20)&.strip&.downcase
          return if role.nil? || role.empty?
          return tell('Your own sysop role stays.') if own? && role == UI::Sysop::ROLE
          return tell("It has no #{role} role.") unless selected.roles.include?(role)

          @accounts.revoke(name, role)
        end

        def ban_or_unban
          return unless name
          return tell('You cannot ban yourself.') if own?
          return unban if selected.banned?

          reason = read_line('Why:', max: 30)
          return if reason.nil? || !yes?("Ban #{name}?", 'Its calls on the gate', 'are hung up.')

          UI::Sysop.ban(@accounts, name, by: sysop, reason: reason)
        end

        def unban
          @accounts.unban(name, by: sysop) if yes?("Lift the ban of #{name}?")
        end

        def new_password
          return unless name && yes?("New password for #{name}?", 'The old one stops working.')

          password = UI::Sysop.new_password(@accounts, name, by: sysop)
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
          return unless name
          return tell('That is you.') if own?
          return tell('No call on the gate.') if UI::Sysop.calls_of(name).empty?

          UI::Sysop.hang_up_calls(name, by: sysop) if yes?("Hang up #{name}?")
        end

        def search
          text = read_line('Find:', text: @query.to_s, max: 20)&.strip
          return if text.nil?

          @query = text.empty? ? nil : text
          @page  = 0
          @index = 0
        end
      end
    end
  end
end
