# frozen_string_literal: true

module UI
  module Petscii
    # The sysop's console (UI::Sysop) on a Commodore 64, opened from SysOp
    # in the caller's profile: a yellow bar on row 0, the view's content, and
    # the hint bar or a line being read on row 24. ← or RUN/STOP goes back;
    # from the first screen back to the profile.
    module Sysop
      # Runs the console for the C64 caller on +session+ with +accounts+
      # (the gate's BBS::Auth::Directory). Returns +nil+.
      def self.run(session, accounts) = Console.new(session).run(Home.new(accounts))

      # The runner of the console's views.
      class Console < BBS::Pages
        # The colour of the console's bar (reversed cells).
        BAR = Canvas::YELLOW
        # Hint of a view a caller without the role sees.
        REFUSED = [['←', true], [' Back', false]].freeze

        def initialize(session) = super(session, face: :petscii, charset: :lower)

        def handle(key)
          return back || true if key == :escape

          page.handle(key)
        end

        def draw(canvas)
          name = Layout.plain(session.identity.name.to_s)[0, 20]
          canvas.text(Layout::BAR_ROW, 0, ' ' * Layout::EDGE, BAR, rvs: true)
          canvas.text(Layout::BAR_ROW, 1, 'TTG GATE  SYSOP', BAR, rvs: true)
          canvas.text(Layout::BAR_ROW, Layout::EDGE - name.length, name, BAR, rvs: true)
          allowed = UI::Sysop.allowed?(session)
          allowed ? page.draw(canvas) : refused(canvas)
          if line
            input_line(canvas)
          else
            Chrome.hint(canvas, allowed ? page.hint : REFUSED)
          end
          cursor(Layout::HINT_ROW, Layout::HINT_WIDTH)
        end

        private

        def refused(canvas)
          Layout.band(canvas, 'NO ENTRY', '', Canvas::LIGHT_RED)
          canvas.text(Layout.row(2), 1, 'The console is for a sysop.', Canvas::LIGHT_GREY)
        end

        def input_line(canvas)
          label = line.label.to_s
          text  = line.text.to_s[-(Layout::HINT_WIDTH - label.length - 2)..] || line.text.to_s
          canvas.text(Layout::HINT_ROW, 0, label, Canvas::LIGHT_GREEN)
          canvas.text(Layout::HINT_ROW, label.length + 1, text, Canvas::WHITE)
          canvas.text(Layout::HINT_ROW, label.length + 1 + text.length, ' ', Canvas::WHITE, rvs: true)
        end
      end

      # What the views of the console share: the accounts, the sysop's name,
      # a yes-or-no question and a notice over the view.
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
          view = Views::TextView.new('SYSOP', lines.map { |l| [l, Canvas::WHITE] }, color: Canvas::YELLOW, hint: YES_NO)
          show(view) { |key| { 'y' => true, 'n' => false, 'escape' => false }[key.to_s.downcase] }
        end

        # Shows +lines+ until a key.
        def tell(*lines)
          show(Views::TextView.new('SYSOP', lines, color: Canvas::YELLOW, hint: [['Press a key', false]]))
        end

        # A thin rule across the content, short of the last column (a C64
        # would wrap there and link the row to the next).
        def rule(canvas, row) = canvas.text(row, 0, '─' * Layout::EDGE, Canvas::DARK_GREY)

        def when_text(iso) = iso ? Time.parse(iso).localtime.strftime('%Y-%m-%d %H:%M') : 'never'

        # The notice line of a view, at content +line+.
        def notice(canvas, line)
          text, color = @notice
          canvas.text(Layout.row(line), 1, Layout.plain(text)[0, Layout::EDGE - 1], color) if text
        end
      end
    end
  end
end
