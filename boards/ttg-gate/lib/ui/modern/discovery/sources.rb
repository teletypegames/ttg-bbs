# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # Where the catalog comes from: every source list with its credit and
      # its records, DB-IP for the countries, and the wiki page of the probe
      # policy and the opt-out.
      class Sources
        include Style

        def initialize(session, browse)
          @session = session
          @browse  = browse
        end

        def run
          lines = [crumbs('SOURCES'), rule, '']
          @browse.sources.each do |s|
            next unless s['last_parse_at']

            lines << "#{GREEN}#{BOLD}#{s['name']}#{RESET}#{DIM}  #{s['record_count'].to_i} telnet boards#{RESET}"
            lines << "#{TEXT}#{fit(s['attribution'], width)}#{RESET}"
          end
          lines.push('', "#{GREEN}#{BOLD}DB-IP#{RESET}#{DIM}  the countries#{RESET}",
                     "#{TEXT}IP Geolocation by DB-IP (db-ip.com), IP to Country Lite, CC BY 4.0#{RESET}", '')
          wrap('Nothing is scanned: we only call the addresses these lists publish, once a day, and never log in. ' \
               "A sysop who wants a board left out, or its banner hidden, finds how on #{BoardPage::WIKI}.")
            .each { |l| lines << "#{DIM}#{l}#{RESET}" }
          lines.fill('', lines.size...(rows - 3))
          lines.push(rule, "#{DIM}Press a key.#{RESET}")
          paint(lines)
          key
        end

        private

        def wrap(text) = BBS::FrameBuffer.wrap_ansi(text, width)
      end
    end
  end
end
