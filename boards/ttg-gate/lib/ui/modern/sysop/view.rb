# frozen_string_literal: true

module UI
  module Modern
    # The sysop's console (UI::Sysop) on a modern terminal, opened from
    # SysOp in the caller's profile: rubbs' BBS::Kit::Modern::Tabs like the
    # gate's own, its tabs CALLS, ACCOUNTS and LOG. TAB or the arrows go
    # round them, Q goes back to the profile.
    module Sysop
      # The console's look: its tabs, its top line, yellow for the sysop.
      LOOK = BBS::Kit::Modern::Look.new(
        tabs:   { calls: 'CALLS', accounts: 'ACCOUNTS', log: 'LOG' },
        crumb:  'SYSOP',
        accent: BBS::Kit::Modern::Palette::YELLOW
      )

      # Runs the console for the caller on +session+ with +accounts+ (the
      # gate's BBS::Auth::Directory). Returns +nil+.
      def self.run(session, accounts)
        sides = { calls: Calls.new(accounts), accounts: Accounts.new(accounts), log: LogView.new(accounts) }
        BBS::Kit::Modern::Tabs.new(session, look: LOOK, sides: sides).run
      end

      # A tab of the console: the logo-less masthead with the tabs, the body,
      # the hints at the bottom. Without the role it shows nothing but that,
      # and every action checks the role again (a logout meanwhile).
      class View < Screen
        key(:tab, :right) { pages.switch }
        key(:left) { pages.switch(-1) }
        key(:escape, 'q', 'Q') { quit }

        def initialize(accounts)
          super()
          @accounts = accounts
        end

        def lines
          return refused unless UI::Sysop.allowed?(session)

          body = [*masthead(tab), *self.body]
          body.fill('', body.size...(rows - 3))
          body.push(rule, "#{DIM}#{fit(hints, width)}#{RESET}")
        end

        private

        def tab = nil

        def body = []

        def hints = 'TAB next tab   Q back'

        def sysop = session.identity.name

        def refused = [crumbs('NO ENTRY'), rule, '', "#{RED}The console is for a sysop.#{RESET}", '', "#{DIM}Q back#{RESET}"]

        # Runs the block when the caller is still a sysop.
        def guarded
          return quit unless UI::Sysop.allowed?(session)

          yield
        end

        # Asks +question+; true on Y, false on N or Esc.
        def yes?(question)
          page = Lines.new(['', "#{YELLOW}#{BOLD}#{plain(question)}#{RESET}", '', "#{DIM}Y yes   N no#{RESET}"])
          show(page) { |key| { 'y' => true, 'n' => false, 'escape' => false, 'q' => false }[key.to_s.downcase] }
        end

        # Shows +lines+ until a key.
        def tell(*lines)
          show(Lines.new(['', *lines.map { |l| "#{TEXT}#{l}#{RESET}" }, '', "#{DIM}Press a key#{RESET}"]))
        end

        # A list's rows around +index+, a page of +size+.
        def window(list, index, size)
          first = index / size * size
          list[first, size].to_a.each_with_index.map { |item, i| yield(item, first + i == index) }
        end

        def per_page = [rows - 16, 3].max

        def when_text(iso) = iso ? Time.parse(iso).localtime.strftime('%Y-%m-%d %H:%M') : 'never'

        def fact(label, value) = "#{DIM}#{label.ljust(13)}#{RESET}#{TEXT}#{plain(value)}#{RESET}"
      end
    end
  end
end
