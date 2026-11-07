# frozen_string_literal: true

module UI
  module Modern
    # The Today tab (Herald): what kind of day it is on the left (name days,
    # holidays, the sun and the moon, the weather, the forint), history and
    # the earthquakes on the right, the network under them. RETURN opens the
    # board of the day's page in Global Discovery; TAB and the arrows turn
    # the tabs, Q hangs up.
    class Today < Screen
      # The columns of the left side.
      LEFT = 38
      # The columns of a label on the left side.
      LABEL = 10
      # Seconds a page is kept before it is made again.
      KEEP = 30
      # Where the parts come from.
      SOURCES = 'Sources: Open-Meteo (CC BY 4.0) · ECB · Wikipedia (CC BY-SA) · USGS'

      key(:tab, :right) { pages.switch }
      key(:left) { pages.switch(-1) }
      key('o', 'O') { pages.open_tab(:own) }
      key('d', 'D', 'g', 'G') { pages.open_tab(:discovery) }
      key('w', 'W') { pages.open_tab(:wall) }
      key('f', 'F') { pages.open_tab(:feedback) }
      key('h', 'H') { pages.open_tab(:hunt) }
      key('p', 'P', 'a', 'A') { pages.profile }
      key(:escape, 'q', 'Q') { quit }
      key(:enter) { board_of_day }

      # [source] answers the Edition now (or +nil+ when there is none)
      # [ctx]    the Discovery::Context of Global Discovery, for the board of
      #          the day's page (or +nil+)
      def initialize(source, ctx: nil)
        super()
        @source = source
        @ctx    = ctx
      end

      # A caller who opens Today has read the day's page (the Newsreader
      # badge).
      def enter
        super
        Rubbs.achieve(:today)
      end

      def lines
        page = edition
        lines = [*masthead(:today), '']
        return lines.push("#{YELLOW}Today's page is not ready yet. Please try again later.#{RESET}") unless page

        lines << date_line(page.day)
        net  = [*network(page.network), *hunt_line]
        body = rows - 3 - lines.size - net.size
        lines.concat(columns(left(page), right(page, body), body))
        lines.push(rule, *net, "#{DIM}#{fit(SOURCES, width)}#{RESET}", hints)
      end

      private

      def edition
        now = Time.now.to_i
        if @made_at.nil? || now - @made_at >= KEEP
          @made_at = now
          @hunt    = hunt_now
          @edition = @source.call
        end
        @edition
      rescue StandardError => e
        Rubbs.log('today', e)
        nil
      end

      def hunt_now
        TTG::Hunt.proxy.trails['season']
      rescue StandardError
        nil
      end

      def hunt_line
        hunt = @hunt or return []
        words = "#{hunt['players']} on the trail · #{hunt['finished']} home"
        title = fit(hunt['title'], 30).rstrip
        ["#{look.accent}#{BOLD}THE HUNT#{RESET}  #{YELLOW}#{BOLD}#{title}#{RESET}  " \
         "#{TEXT}#{fit("#{words}  H open", width - title.length - 12).rstrip}#{RESET}"]
      end

      def date_line(day)
        right = "day #{day.date.yday} · week #{day.date.cweek}"
        left  = day.date.strftime('%A, %-d %B %Y').upcase
        "#{look.accent}#{BOLD}#{left}#{RESET}#{' ' * [width - left.length - right.length, 1].max}#{DIM}#{right}#{RESET}"
      end

      def columns(left, right, count)
        (0...count).map do |i|
          "#{pad_ansi(left[i].to_s, LEFT)}  #{right[i]}"
        end
      end

      def pad_ansi(text, size) = text + (' ' * [size - visible(text).length, 0].max)

      def visible(text) = text.gsub(/\e\[[\d;]*m/, '')

      def left(page)
        day = page.day
        lines = []
        lines << pair('Name day', day.namedays.join(', ')) if day.namedays.any?
        lines.concat(holidays(day))
        lines << pair('Sky', sky(day))
        here, there = page.weather
        lines.concat(weather(here)) if here
        lines << pair(there.place, "#{there.temp.round}°C #{there.words}", YELLOW) if there
        lines.concat(rates(page.rates))
      end

      def holidays(day)
        day.holidays.first(2).map { |h| pair(h.public ? 'Holiday' : 'Today', h.name, h.public ? GREEN : TEXT) }
      end

      def pair(label, value, color = TEXT)
        "#{DIM}#{label.ljust(LABEL)}#{RESET}#{color}#{fit(value, LEFT - LABEL)}#{RESET}"
      end

      def sky(day)
        moon = "#{day.moon.mark} #{day.moon.percent}%"
        return moon unless day.sunrise

        "↑#{day.sunrise.strftime('%H:%M')} ↓#{day.sunset.strftime('%H:%M')}  moon #{moon}"
      end

      def weather(forecast)
        lines = [pair(forecast.place, "#{forecast.temp.round}°C #{forecast.words}", YELLOW)]
        days = [['today', forecast.today], ['tmrw', forecast.tomorrow]].select(&:last)
        lines << pair('', days.map { |name, d| "#{name} #{d.low.round}…#{d.high.round}°" }.join(' · ')) if days.any?
        lines
      end

      def rates(rates)
        return [] unless rates

        cells = rates.huf.map { |c, v| "#{c} #{format('%.2f', v)}" }
        ["#{DIM}#{'Forint'.ljust(LABEL)}#{RESET}#{TEXT}#{fit(cells.first(2).join('  '), LEFT - LABEL)}#{RESET}",
         "#{DIM}#{"ECB #{rates.date[5..]}".ljust(LABEL)}#{RESET}#{TEXT}#{fit(cells.drop(2).join('  '), LEFT - LABEL)}#{RESET}"]
      end

      def right_width = width - LEFT - 2

      def right(page, count)
        quakes = quake_lines(page.quakes, count >= 12 ? 3 : 2)
        room = [count - quakes.size, 2].max
        [*events(page.events, room), *quakes].first(count)
      end

      def events(events, room)
        return [] if events.empty?

        lines = ["#{look.accent}#{BOLD}ON THIS DAY#{RESET}"]
        events.each do |e|
          break if lines.size >= room - 1

          lines << "#{YELLOW}#{e.year.to_s.rjust(4)}#{RESET} #{TEXT}#{fit(e.text, right_width - 5)}#{RESET}"
        end
        lines << ''
      end

      def quake_lines(quakes, shown)
        return [] if quakes.empty?

        now = Time.now.to_i
        ["#{look.accent}#{BOLD}EARTHQUAKES#{RESET} #{DIM}M4.5+, 24 hours#{RESET}",
         *quakes.first(shown).map do |q|
           ago = Rubbs::Petscii::Kit::Layout.age(q.time, now)
           "#{RED}#{format('%.1f', q.mag)}#{RESET} #{TEXT}#{fit(q.place, right_width - 9)}#{RESET} #{DIM}#{ago.rjust(4)}#{RESET}"
         end]
      end

      def network(net)
        return ["#{DIM}The network is quiet.#{RESET}", '', ''] unless net

        [network_line(net), ours_line(net.ours), net.board_of_day ? board_line(net.board_of_day) : wall_line(net.walls.last)]
      end

      def network_line(net)
        words = "#{net.callers} on the gate · #{net.boards} boards · #{net.online} online worldwide, #{net.fresh} new"
        "#{look.accent}#{BOLD}THE NETWORK#{RESET}  #{TEXT}#{fit(words, width - 13).rstrip}#{RESET}"
      end

      def ours_line(ours)
        return '' unless ours

        number, board = ours
        name = board.name
        "#{DIM}Ours today  O #{number}#{RESET} #{YELLOW}#{BOLD}#{name}#{RESET}  " \
          "#{TEXT}#{fit(board.summary, width - name.length - number.to_s.length - 17).rstrip}#{RESET}"
      end

      def board_line(board)
        return '' unless board

        name = fit(board.title, 30).rstrip
        "#{DIM}Board of the day#{RESET}  #{GREEN}#{BOLD}#{name}#{RESET}  " \
          "#{DIM}#{fit("#{board.address}  RETURN", width - name.length - 20).rstrip}#{RESET}"
      end

      def wall_line(note)
        return '' unless note

        name = fit(note['name'], 16).rstrip
        "#{DIM}On the wall#{RESET}  #{YELLOW}#{name}#{RESET}  #{TEXT}#{fit(note['text'], width - name.length - 15)}#{RESET}"
      end

      def board_of_day
        board = edition&.network&.board_of_day
        return unless board && @ctx&.browse

        Discovery::BoardPage.open(self, @ctx, board.id, path: 'BOARD OF THE DAY')
      end

      def hints
        "#{DIM}RETURN board of the day  TAB tabs  H hunt  W wall  F feedback  P profile  Q hang up#{RESET}"
      end
    end
  end
end
