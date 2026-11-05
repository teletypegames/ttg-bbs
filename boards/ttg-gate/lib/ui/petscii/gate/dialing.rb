# frozen_string_literal: true

module UI
  module Petscii
    class Gate < BBS::Kit::Petscii::Frame
      # The calls of the gate: our own boards with a little show, the
      # catalog's by the dial rules, and a stored PETSCII banner.
      module Dialing
        # The keys of a warning's question: Y dials, N goes back.
        ANSWERS = {
          'y'     => true,
          'Y'     => true,
          'n'     => false,
          'N'     => false,
          :escape => false,
          'q'     => false,
          'Q'     => false
        }.freeze

        private

        # Our own board: its row flashes, the handshake fills the hint bar, the
        # line goes to the board, and the whole screen again when it hangs up.
        def dial_own(board)
          2.times do
            flash(true)
            flash(false)
          end
          (0..10).step(2) { |filled| status([['Handshake ', false], ['█' * filled, true], ['▒' * (10 - filled), false]]) }
          status([['Carrier detected', true]])
          @status = nil
          hand_over { UI.dial(session, board) }
        end

        def flash(on)
          own.flash = on
          redraw
          sleep STEP
        end

        def status(parts)
          @status = parts
          redraw
          sleep STEP
        end

        # A board of the catalog, by the dial rules: a dead one asks first, a
        # refused one says why.
        def dial_catalog(listing)
          return unless @dials.warnings(listing, face: :petscii).all? { |w| confirm(listing, w) }

          caller = UI.caller_key(session)
          refusal = @dials.check(caller, listing, face: :petscii)
          return refused(listing, refusal) if refusal

          result = hand_over { UI.dial_catalog(session, @dials, caller, listing, face: :petscii) }
          refreshed = @browse.page(listing.id)
          view.refresh(refreshed) if refreshed && view.is_a?(Views::PageView)
          refused(listing, result) if result.is_a?(::Discovery::DialService::Refusal)
        end

        def confirm(listing, warning)
          question = Views::TextView.new(
            Layout.plain(listing.title),
            WARNINGS.fetch(warning, []).map { |l| [l, Canvas::YELLOW] },
            color: Canvas::YELLOW,
            keys:  [%w[Y Dial], %w[N Back]]
          )
          pop_up(question, hint: [['Y', true], [' Dial  ', false], ['N', true], [' Back', false]]) { |key| ANSWERS[key] }
        end

        def refused(listing, refusal)
          pop_up(notice(Layout.plain(listing.title), REFUSALS.fetch(refusal.reason, ['The call did not go.'])))
        end

        # The first screen of a PETSCII banner as it came, until a key; then
        # the whole screen again.
        def banner(page)
          hand_over do
            session.write_raw([Canvas::UPPERCASE, Canvas::CLEAR].pack('C*') + ::Discovery::BannerPreview.petscii(page.c64_banner))
            wait_key
          end
        end
      end
    end
  end
end
