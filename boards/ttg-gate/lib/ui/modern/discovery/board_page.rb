# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # The page of one board of the catalog: its address and state, the
      # last answer, the uptime strip of 30 days, the fields with the source
      # of each, the tags, the lists that name it, the banner (B shows its
      # first screen) and the Dial button (RETURN or D). Q or Esc goes back.
      class BoardPage < Screen
        WIKI = 'wiki.teletypegames.org/services/ttg-gate-bbs'
        # The width of a field's label.
        LABEL = 13
        # Why a call failed, from our server: the words of a probe's result.
        FAILURES = {
          'dns_fail' => 'the name does not resolve (the domain may be gone)',
          'timeout' => 'no answer in time (it may be a firewall, or the machine is off)',
          'refused' => 'the port is closed (the board is not running)',
          'closed' => 'it hung up at once'
        }.freeze
        REFUSALS = {
          rate: 'You have dialled %<limit>d boards in 10 minutes. The next line is free in %<wait>s.',
          busy: '%<limit>d callers of the gate are on this board already. Try again in a minute.',
          not_petscii: 'This board has no PETSCII face.',
          not_public: 'This board is not on the public internet; the gate does not call it.',
          unknown: 'This board is not in the catalog any more.'
        }.freeze

        # The keys of a warning's question: Y dials, N goes back.
        ANSWERS = { 'y' => true, 'Y' => true, 'n' => false, 'N' => false, :escape => false, 'q' => false,
                    'Q' => false }.freeze

        WARNINGS = {
          petscii_only: ['This board is made for a Commodore 64.',
                         'It speaks PETSCII, which a modern terminal shows as noise. Dial anyway?'],
          dead: ['This board has not answered our calls for 30 days or more.',
                 'It may be gone for good. Dial anyway? Your call is recorded as one of ours.']
        }.freeze

        key(:enter, 'd', 'D') { dial }
        key('b', 'B') { banner }
        key(:escape, :left, 'q', 'Q') { back }

        # Pushes the page of the board +id+ over +from+ (a page of the
        # gate), unless the board is gone from the catalog.
        def self.open(from, ctx, id, path:)
          page = new(ctx, id, path: path)
          from.push(page) if page.reload
        end

        def initialize(ctx, id, path:)
          super()
          @ctx  = ctx
          @id   = id
          @path = path
        end

        # The board's page as the catalog has it now; nil when it is gone.
        def reload = @page = @ctx.browse.page(@id)

        # Each key reloads the page; a board gone from the catalog goes back.
        def handle(key)
          taken = super
          back if pages.page.equal?(self) && !reload
          taken
        end

        def lines
          lines = [header, rule, '', *status, '', *fields, *tag_lines]
          lines << "#{DIM}#{fit('Banner', LABEL)}#{TEXT}#{banner_note}#{RESET}"
          lines.fill('', lines.size...(rows - 4))
          lines.push(rule, dial_line, "#{DIM}#{fit("How we call boards, and opting out: #{WIKI}", width)}#{RESET}")
        end

        private

        def listing = @page.listing

        def header = crumbs("#{@path} › #{listing.title}", listing.address)

        # The state, the last answer, why the last call failed, the strip.
        def status
          color = STATE_COLORS.fetch(listing.state, TEXT)
          ["#{mark(listing)} #{color}#{BOLD}#{listing.state.upcase}#{RESET}  #{TEXT}#{answer}#{RESET}",
           failure && "#{DIM}  #{failure}#{RESET}",
           "#{DIM}Last 30 days #{RESET}#{LINE}[#{GREEN}#{strip}#{LINE}]#{RESET}#{DIM} █ answered  · no answer#{RESET}"].compact
        end

        # The fields with their sources, and the lists that name the board.
        def fields
          lines = @page.fields.map do |f|
            "#{DIM}#{fit(f.label, LABEL)}#{TEXT}#{fit(f.value, width - LABEL - 21)}#{RESET} #{DIM}#{fit(f.source, 20)}#{RESET}"
          end
          lines << "#{DIM}#{fit('Listed by', LABEL)}#{TEXT}#{fit(@page.source_names.join(', '), width - LABEL)}#{RESET}"
        end

        def tag_lines
          tags = BBS::FrameBuffer.wrap_ansi(shown_tags.join(' · '), width - LABEL)
          tags.first(2).each_with_index.map { |t, i| "#{DIM}#{fit(i.zero? ? 'Tags' : '', LABEL)}#{TEXT}#{t}#{RESET}" }
        end

        # The tags but the claims of the sources (claims:petscii is searched,
        # not shown: only our calls say what a board speaks).
        def shown_tags = listing.tags.reject { |t| t.start_with?(::Discovery::TagService::CLAIMS) }.map { |t| plain(t) }

        def answer
          return 'not called yet' unless listing.first_probe_at

          ok = @page.last_success_at
          text = ok ? "last answered #{date(ok)}" : 'never answered our calls'
          text += ", in #{@page.latency_ms} ms" if ok && @page.latency_ms && %w[online flaky].include?(listing.state)
          text += ' · delisted' if @page.delisted?
          text
        end

        def failure
          return unless %w[down dead flaky].include?(listing.state)

          reason = FAILURES[@page.last_result]
          reason && "From our server: #{reason}."
        end

        def strip = @page.strip.gsub(::Discovery::BoardPageModel::DOWN, "#{RED}·#{GREEN}")

        def banner_note
          return "hidden at the sysop's request" unless listing.preview?
          return 'PETSCII to a C64: it shows on the C64 face' if !@page.banner && @page.c64_banner
          return 'none stored yet' unless @page.banner
          return 'PETSCII: it shows on the C64 face' if @page.encoding == 'petscii'

          note = "#{@page.banner.bytesize} bytes of #{date(@page.banner_at)} · B shows it"
          @page.c64_banner ? "#{note} · a C64 gets PETSCII" : note
        end

        def dial_line
          warn = ' C64 board' if listing.petscii_only?
          warn = ' no answer for 30 days' if listing.dead?
          "#{SELECTED}#{GREEN}#{BOLD} DIAL > #{RESET}#{DIM}  RETURN dials#{"  ·#{warn}" if warn}   B banner   Q back#{RESET}"
        end

        def dial
          return unless @ctx.dials.warnings(listing, face: :modern).all? { |w| confirm(w) }

          caller = UI.caller_key(session)
          refusal = @ctx.dials.check(caller, listing, face: :modern)
          return refused(refusal) if refusal

          result = hand_over { UI.dial_catalog(session, @ctx.dials, caller, listing, face: :modern) }
          refused(result) if result.is_a?(::Discovery::DialService::Refusal)
        end

        def confirm(warning)
          lines = [header, rule, '']
          WARNINGS.fetch(warning).each { |l| lines << "#{YELLOW}#{l}#{RESET}" }
          lines.push('', "#{GREEN}#{BOLD}Y#{RESET}#{DIM} dial   #{RESET}#{GREEN}#{BOLD}N#{RESET}#{DIM} back#{RESET}")
          show(Lines.new(lines)) { |key| ANSWERS[key] }
        end

        def refused(refusal)
          text = format(REFUSALS.fetch(refusal.reason), limit: limit(refusal.reason), wait: wait(refusal.wait))
          show(Lines.new([header, rule, '', "#{YELLOW}#{text}#{RESET}", '', "#{DIM}Press a key.#{RESET}"]))
        end

        def limit(reason) = reason == :rate ? ::Discovery::DialService::PER_CALLER : ::Discovery::DialService::PER_HOST

        def wait(seconds)
          seconds = seconds.to_i
          seconds >= 60 ? "#{(seconds + 59) / 60} minutes" : "#{seconds} seconds"
        end

        # The first screen of the stored banner, played as it came (only
        # its colours, moves and text), and a line under it.
        def banner
          bytes = @page.banner
          return unless bytes && @page.encoding != 'petscii'

          hand_over do
            session.write(::Discovery::BannerPreview.ansi(bytes))
            session.write("#{RESET}\e[#{rows};1H\e[K#{SELECTED}#{DIM} The banner of #{plain(listing.title)}, " \
                          "#{date(@page.banner_at)}. Press a key. #{RESET}")
            pages.wait_key
          end
        end
      end
    end
  end
end
