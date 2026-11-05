# frozen_string_literal: true

module UI
  module Modern
    # The sysop's console (UI::Sysop) on a modern terminal, opened from
    # SysOp in the caller's profile: pages of its own runner (Console),
    # until Q on its first screen goes back to the profile.
    module Sysop
      # Runs the console for the caller on +session+ with +accounts+ (the
      # gate's BBS::Auth::Directory). Returns +nil+.
      def self.run(session, accounts) = Console.new(session).run(Home.new(accounts))

      # The runner of the console's pages, its line read at the bottom of
      # the screen.
      class Console < BBS::Pages
        include Style
        include Prompt

        def initialize(session) = super(session, face: :modern)

        def draw(frame)
          super
          prompt(frame) if line
        end
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
          return refused unless UI::Sysop.allowed?(session)

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
          return back unless UI::Sysop.allowed?(session)

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
