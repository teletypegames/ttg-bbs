# frozen_string_literal: true

module UI
  module Petscii
    # The sysop's console (UI::Sysop) on a Commodore 64, opened from SysOp
    # in the caller's profile: a Rubbs::Petscii::Kit::Frame like the gate's
    # own screens, its tabs CALLS, ACCOUNTS, FEEDBACK, WALL and LOG. ← or RUN/STOP on the
    # first screen goes back to the profile.
    module Sysop
      # The console's frame: the tabs and their letters.
      CHROME = Rubbs::Petscii::Kit::Chrome.new(
        title:   'SYSOP',
        places:  [[:calls, 'CALLS'], [:accounts, 'ACCOUNTS'], [:feedback, 'FEEDBACK'], [:wall, 'WALL'], [:log, 'LOG']],
        hotkeys: { 'c' => :calls, 'a' => :accounts, 'f' => :feedback, 'w' => :wall, 'l' => :log }
      )

      # Runs the console for the C64 caller on +session+ with +accounts+
      # (the gate's Rubbs::Common::Auth::Directory). Returns +nil+.
      def self.run(session, accounts) = Console.new(session, accounts).run

      # The runner of the console's tabs.
      class Console < Rubbs::Petscii::Kit::Frame
        # What a caller without the role sees.
        REFUSED = Views::TextView.new(
          'NO ENTRY',
          [['The console is for a sysop.', Canvas::LIGHT_GREY]],
          color: Canvas::LIGHT_RED,
          hint:  [['←', true], [' Back', false]]
        )

        def initialize(session, accounts)
          @accounts = accounts
          super(session, chrome: CHROME, home: :calls)
        end

        # The view on top; the refusal for a caller without the role.
        def view = UI::Sysop.allowed?(session) ? page : REFUSED

        def section_view(key)
          @views ||= {}
          @views[key] ||= {
            calls:    CallsView,
            accounts: AccountsView,
            feedback: FeedbackView,
            wall:     WallView,
            log:      LogView
          }[key]&.new(@accounts)
        end

        # Under the tabs: the calls and the accounts in numbers.
        def top_line(canvas)
          stats = @accounts.statistics
          chrome.line(canvas, [[Rubbs.calls.size.to_s, Canvas::WHITE], [' on  ', Canvas::GREY],
                               [stats[:accounts].to_s, Canvas::WHITE], [' accounts  ', Canvas::GREY],
                               [stats[:seen_day].to_s, Canvas::WHITE], [' today', Canvas::GREY]])
        end
      end

      # What the views of the console share: the sysop's name, a yes-or-no
      # question and a notice over the view, a list row in the gate's way.
      module Shared
        YES_NO = [['Y', true], [' Yes  ', false], ['N', true], [' No', false]].freeze

        private

        def sysop = session.identity.name

        # Runs the block when the caller is still a sysop.
        def guarded
          return pages.back unless UI::Sysop.allowed?(session)

          yield
        end

        # Asks +lines+; true on Y, false on N, ← or RUN/STOP.
        def yes?(*lines)
          view = Views::TextView.new('SYSOP', lines.map { |l| [l, Canvas::WHITE] }, color: Canvas::YELLOW)
          pages.pop_up(view, hint: YES_NO) { |key| { 'y' => true, 'n' => false, 'escape' => false }[key.to_s.downcase] }
        end

        # Shows +lines+ until a key.
        def tell(*lines) = pages.pop_up(Views::TextView.new('SYSOP', lines, color: Canvas::YELLOW))

        def when_text(iso) = iso ? Time.parse(iso).localtime.strftime('%Y-%m-%d %H:%M') : 'never'

        # A row of the list like the gate's: its number, +name+, a dotted
        # leader and +right+; the lit one a cyan bar.
        def list_row(canvas, row, slot, name, right, name_color: Canvas::WHITE, mark: nil)
          number = format('%02d', ((@page * @per_page) + slot + 1) % 100)
          name   = Layout.plain(name)[0, 26]
          mark   = mark ? mark[0] : ' '
          leader = " #{'.' * [Layout::WIDTH - 6 - name.length - right.length - 2, 0].max} "
          if slot == @index
            return canvas.text(
              row,
              0,
              "#{number} #{mark}#{name}#{leader}#{right}".ljust(Layout::WIDTH),
              Canvas::CYAN,
              rvs: true
            )
          end

          Layout.runs(canvas, row, 0, [[number, Canvas::YELLOW], [' ', nil], [mark, Canvas::LIGHT_RED], [name, name_color],
                                       [leader, Canvas::DARK_GREY], [right, Canvas::CYAN]])
        end

        # Facts under the rule at +top+: [label, value, colour] each.
        def facts(canvas, top, facts)
          Layout.rule(canvas, top)
          facts.each_with_index do |(label, value, color), i|
            Layout.runs(canvas, top + 1 + i, 1, [[label.ljust(8), Canvas::GREY], [Layout.plain(value.to_s), color || Canvas::LIGHT_GREY]])
          end
        end
      end
    end
  end
end
