# frozen_string_literal: true

module UI
  module Modern
    # The sysop's console of the gate on a modern terminal: the calls on the
    # gate (and hanging one up), the accounts of the network (roles, bans, a
    # new password) and the gate's log, for a caller with the +sysop+ role.
    # P opens the profile to log in; S on Own Servers opens the console.
    module Sysop
      # The role that opens the console.
      ROLE = 'sysop'

      # Whether the caller on +session+ may use the console.
      def self.allowed?(session) = session.identity.role?(ROLE)

      # The calls on the gate of the account +name+.
      def self.calls_of(name)
        key = BBS::Auth::Names.key(name)
        BBS.calls.select { |call| call.caller_name && BBS::Auth::Names.key(call.caller_name) == key }
      end

      # A screen of the console: the top line (SYSOP › where), the body,
      # the hints at the bottom. Without the role it shows nothing but that,
      # and every action checks the role again (a logout meanwhile).
      class View < Screen
        def initialize(accounts)
          super()
          @accounts = accounts
        end

        def lines
          return refused unless Sysop.allowed?(session)

          body = self.body
          body.fill('', body.size...(rows - 3))
          body.push(rule, "#{DIM}#{fit(hints, width)}#{RESET}")
        end

        private

        def body = []

        def hints = 'Q back'

        def sysop = session.identity.name

        def refused = [header('NO ENTRY'), rule, '', "#{RED}The console is for a sysop.#{RESET}", '', "#{DIM}Q back#{RESET}"]

        # The top line: where the console is, and +right+.
        def header(path, right = '')
          right = plain(right)
          left  = fit("SYSOP › #{path}", width - right.length - 1).rstrip
          "#{YELLOW}#{BOLD}#{left}#{RESET}#{' ' * [width - left.length - right.length, 1].max}#{DIM}#{right}#{RESET}"
        end

        # Runs the block when the caller is still a sysop.
        def guarded
          return back unless Sysop.allowed?(session)

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

        def per_page = [rows - 7, 3].max

        def when_text(iso) = iso ? Time.parse(iso).localtime.strftime('%Y-%m-%d %H:%M') : 'never'
      end
    end
  end
end
