# frozen_string_literal: true

module UI
  module Petscii
    class Gate
      # The calls of the gate: our own boards with a little show, the
      # catalog's by the dial rules, and a stored PETSCII banner.
      module Dialing
        private

        # Our own board: its row flashes, the handshake fills the hint bar, the
        # line goes to the board, and the whole screen again when it hangs up.
        def dial_own(board)
          2.times do
            own.flash = true
            paint
            sleep STEP
            own.flash = false
            paint
            sleep STEP
          end
          (0..10).step(2) do |filled|
            @status = [['Handshake ', false], ['█' * filled, true], ['▒' * (10 - filled), false]]
            paint
            sleep STEP
          end
          @status = [['Carrier detected', true]]
          paint
          sleep STEP
          @status = nil
          hand_over { UI.dial(@screen.session, board) }
          nil
        end

        # A board of the catalog, by the dial rules: a dead one asks first, a
        # refused one says why.
        def dial_catalog(listing)
          return unless @dials.warnings(listing, face: :petscii).all? { |w| confirm(listing, w) }

          caller = UI.caller_key(@screen.session)
          refusal = @dials.check(caller, listing, face: :petscii)
          return refused(listing, refusal) if refusal

          result = nil
          hand_over { result = UI.dial_catalog(@screen.session, @dials, caller, listing, face: :petscii) }
          refreshed = @browse.page(listing.id)
          view.replace(refreshed) if refreshed && view.respond_to?(:replace) && view.is_a?(Views::PageView)
          refused(listing, result) if result.is_a?(::Discovery::DialService::Refusal)
          nil
        end

        def hand_over
          @screen.raw([Canvas::LOWERCASE, Canvas::CLEAR].pack('C*'))
          yield
        ensure
          @stats = stats
          @shown = nil
        end

        def confirm(listing, warning)
          question = Views::TextView.new(Layout.plain(listing.title), WARNINGS.fetch(warning, []).map { |l| [l, Canvas::YELLOW] },
                                         color: Canvas::YELLOW, keys: [%w[Y Dial], %w[N Back]])
          loop do
            case show(question, hint: [['Y', true], [' Dial  ', false], ['N', true], [' Back', false]])
            when 'y', 'Y' then return true
            when 'n', 'N', :escape, 'q', 'Q' then return false
            end
          end
        end

        def refused(listing, refusal)
          show(notice(Layout.plain(listing.title), REFUSALS.fetch(refusal.reason, ['The call did not go.'])))
          nil
        end

        # The first screen of a PETSCII banner as it came, until a key; then
        # the whole screen again.
        def banner(page)
          @screen.raw([Canvas::UPPERCASE, Canvas::CLEAR].pack('C*') + ::Discovery::BannerPreview.petscii(page.c64_banner))
          wait
          @shown = nil
          nil
        end
      end
    end
  end
end
