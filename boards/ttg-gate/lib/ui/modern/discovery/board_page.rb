# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # The page of one board of the catalog: its address and state, the
      # last answer, the uptime strip of 30 days, the fields with the source
      # of each, the tags, the lists that name it, the banner (B shows its
      # first screen) and the Dial button (RETURN or D). Q or Esc goes back.
      class BoardPage
        include Style

        WIKI = 'wiki.teletypegames.org/services/ttg-gate-bbs'
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
          unknown: 'This board is not in the catalog any more.'
        }.freeze

        WARNINGS = {
          petscii_only: ['This board is made for a Commodore 64.',
                         'It speaks PETSCII, which a modern terminal shows as noise. Dial anyway?'],
          dead: ['This board has not answered our calls for 30 days or more.',
                 'It may be gone for good. Dial anyway? Your call is recorded as one of ours.']
        }.freeze

        def initialize(ctx, id, path:)
          @ctx     = ctx
          @session = ctx.session
          @id      = id
          @path    = path
        end

        def run
          loop do
            @page = @ctx.browse.page(@id)
            return unless @page

            draw
            case key
            when :enter, 'd', 'D' then dial
            when 'b', 'B' then banner
            when :escape, :left, 'q', 'Q' then return
            end
          end
        end

        private

        def listing = @page.listing

        def draw
          lines = [crumbs("#{@path} › #{listing.title}", listing.address), rule, '']
          lines << "#{mark(listing)} #{STATE_COLORS.fetch(listing.state, TEXT)}#{BOLD}#{listing.state.upcase}#{RESET}  " \
                   "#{TEXT}#{answer}#{RESET}"
          lines << "#{DIM}  #{failure}#{RESET}" if failure
          lines << "#{DIM}Last 30 days #{RESET}#{LINE}[#{GREEN}#{strip}#{LINE}]#{RESET}#{DIM} █ answered  · no answer#{RESET}"
          lines << ''
          label = 13
          @page.fields.each do |f|
            value = width - label - 21
            lines << "#{DIM}#{fit(f.label, label)}#{TEXT}#{fit(f.value, value)}#{RESET} #{DIM}#{fit(f.source, 20)}#{RESET}"
          end
          lines << "#{DIM}#{fit('Listed by', label)}#{TEXT}#{fit(@page.source_names.join(', '), width - label)}#{RESET}"
          tags = BBS::FrameBuffer.wrap_ansi(listing.tags.join(' · '), width - label)
          tags.first(2).each_with_index { |t, i| lines << "#{DIM}#{fit(i.zero? ? 'Tags' : '', label)}#{TEXT}#{t}#{RESET}" }
          lines << "#{DIM}#{fit('Banner', label)}#{TEXT}#{banner_note}#{RESET}"
          lines.fill('', lines.size...(rows - 4))
          lines.push(rule, dial_line, "#{DIM}#{fit("How we call boards, and opting out: #{WIKI}", width)}#{RESET}")
          paint(lines)
        end

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
          return 'none stored yet' unless @page.banner
          return 'PETSCII: it shows on the C64 face' if @page.encoding == 'petscii'

          "#{@page.banner.bytesize} bytes of #{date(@page.banner_at)} · B shows it"
        end

        def dial_line
          warn = ' C64 board' if listing.petscii_only?
          warn = ' no answer for 30 days' if listing.dead?
          "#{SELECT}#{GREEN}#{BOLD} DIAL > #{RESET}#{DIM}  RETURN dials#{"  ·#{warn}" if warn}   B banner   Q back#{RESET}"
        end

        def dial
          return unless @ctx.dials.warnings(listing, face: :modern).all? { |w| confirm(w) }

          caller = UI.caller_key(@session)
          refusal = @ctx.dials.check(caller, listing, face: :modern)
          return refused(refusal) if refusal

          clear
          result = UI.dial_catalog(@session, @ctx.dials, caller, listing, face: :modern)
          restore
          refused(result) if result.is_a?(::Discovery::DialService::Refusal)
        end

        def confirm(warning)
          lines = [crumbs("#{@path} › #{listing.title}", listing.address), rule, '']
          WARNINGS.fetch(warning).each { |l| lines << "#{YELLOW}#{l}#{RESET}" }
          lines.push('', "#{GREEN}#{BOLD}Y#{RESET}#{DIM} dial   #{RESET}#{GREEN}#{BOLD}N#{RESET}#{DIM} back#{RESET}")
          paint(lines)
          loop do
            case key
            when 'y', 'Y' then return true
            when 'n', 'N', :escape, 'q', 'Q' then return false
            end
          end
        end

        def refused(refusal)
          text = format(REFUSALS.fetch(refusal.reason), limit: limit(refusal.reason), wait: wait(refusal.wait))
          lines = [crumbs("#{@path} › #{listing.title}", listing.address), rule, '', "#{YELLOW}#{text}#{RESET}", '',
                   "#{DIM}Press a key.#{RESET}"]
          paint(lines)
          key
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

          clear
          @session.write(::Discovery::BannerPreview.ansi(bytes))
          @session.write("#{RESET}\e[#{rows};1H\e[K#{SELECT}#{DIM} The banner of #{listing.title}, #{date(@page.banner_at)}. " \
                         "Press a key. #{RESET}")
          key
          restore
        end
      end
    end
  end
end
