# frozen_string_literal: true

module UI
  module Petscii
    module Views
      # The Today tab on a C64 (Herald): four pages, + and - turn them. DAY:
      # the date, the name days, the holidays, the sun, the moon and the
      # weather; WORLD: the forint and the earthquakes; HISTORY: on this day;
      # NETWORK: the gate, the catalog, the board of the day (RETURN opens
      # its page) and the walls.
      class TodayView < Rubbs::Petscii::Kit::View
        # The pages, in order.
        PAGES = %i[day world history network].freeze
        # The title of each page.
        TITLES = { day: 'TODAY', world: 'THE WORLD', history: 'ON THIS DAY', network: 'THE NETWORK' }.freeze
        # The rows a page has under its title.
        ROOM = Layout::ROWS - 2
        # The columns of a line.
        COLS = Layout::EDGE - 1
        # Where a page's parts come from.
        CREDITS = {
          day:     'Weather: Open-Meteo, CC BY 4.0',
          world:   'Rates: ECB  Quakes: USGS',
          history: 'Wikipedia, CC BY-SA'
        }.freeze
        HINT = [['+/-', true], [' Page  ', false], ['O', true], [' Own  ', false], ['D', true], [' Discover', false]].freeze

        key('+') { turn(1) }
        key('-') { turn(-1) }
        key(:right) { turn(1) }
        key(:left) { turn(-1) }
        key(:enter) { open_board }

        # [edition] a Herald::Edition, or +nil+ when there is none yet
        # [on_open] called with the board of the day's listing
        def initialize(edition, on_open:)
          super()
          @edition = edition
          @on_open = on_open
          @page    = 0
        end

        # The Herald::Edition shown, or +nil+.
        attr_reader :edition

        def section = :today

        def hint
          network? && @edition&.network&.board_of_day ? [['RETURN', true], [' Open board  ', false], *HINT.first(2)] : HINT
        end

        def draw(canvas)
          key = PAGES[@page]
          Layout.band(canvas, TITLES.fetch(key), "#{@page + 1}/#{PAGES.size}", Canvas::LIGHT_BLUE)
          lines = @edition ? public_send(key) : [['Today\'s page is not ready yet.', Canvas::YELLOW]]
          lines.first(ROOM).each_with_index { |line, i| put(canvas, Layout.row(1 + i), line) }
          credit = CREDITS[key]
          canvas.text(Layout.row(ROOM + 1), 1, credit, Canvas::DARK_GREY) if credit && @edition
        end

        # The DAY page.
        def day
          d = @edition.day
          [[d.date.strftime('%A %-d %B %Y'), Canvas::WHITE], ["Day #{d.date.yday}, week #{d.date.cweek}", Canvas::GREY], '',
           *namedays(d), *d.holidays.map { |h| [h.name, h.public ? Canvas::LIGHT_GREEN : Canvas::LIGHT_GREY] }, '',
           *sky(d), '', *@edition.weather.flat_map { |w| forecast(w) }]
        end

        # The WORLD page.
        def world
          [*rates(@edition.rates), '', ['Earthquakes M4.5+, 24 hours', Canvas::CYAN], *quakes(@edition.quakes)]
        end

        # The HISTORY page.
        def history
          return [['Nothing for today yet.', Canvas::YELLOW]] if @edition.events.empty?

          lines = []
          @edition.events.each do |e|
            text = Layout.wrap(e.text, COLS - 5, 4)
            break if lines.size + text.size > ROOM - 1

            lines << [[e.year.to_s.rjust(4), Canvas::YELLOW], [" #{text.first}", Canvas::LIGHT_GREY]]
            text.drop(1).each { |l| lines << "     #{l}" }
          end
          lines
        end

        # The NETWORK page.
        def network
          net = @edition.network
          return [['The network is quiet.', Canvas::YELLOW]] unless net

          [[[net.callers.to_s, Canvas::WHITE], [' on the gate now', Canvas::GREY]],
           [[net.boards.to_s, Canvas::WHITE], [' boards of ours', Canvas::GREY]],
           [[net.online.to_s, Canvas::WHITE], [' boards online in the world', Canvas::GREY]],
           [[net.fresh.to_s, Canvas::WHITE], [' new this week', Canvas::GREY]], '',
           *ours(net.ours), *net.notes.flat_map { |name, note| note(name, note) }, *board(net.board_of_day), *walls(net.walls)]
        end

        private

        def network? = PAGES[@page] == :network

        def turn(step) = @page = (@page + step).clamp(0, PAGES.size - 1)

        def open_board
          board = network? && @edition&.network&.board_of_day
          board ? @on_open.call(board) : pass
        end

        def put(canvas, row, line)
          case line
          when String then canvas.text(row, 1, Layout.plain(line)[0, COLS], Canvas::LIGHT_GREY)
          when Array
            runs = line.first.is_a?(Array) ? line : [line]
            Layout.runs(canvas, row, 1, runs.map { |t, c| [Layout.plain(t), c] })
          end
        end

        def namedays(day)
          return [] if day.namedays.empty?

          [['Name day (HU)', Canvas::CYAN], *Layout.wrap(day.namedays.join(', '), COLS, 2).map { |l| [l, Canvas::YELLOW] }]
        end

        def sky(day)
          sun = day.sunrise ? ["Sunrise #{day.sunrise.strftime('%H:%M')}  Sunset #{day.sunset.strftime('%H:%M')}"] : []
          [*sun, "Moon: #{day.moon.name}, #{day.moon.percent}%"]
        end

        def forecast(weather)
          lines = [[[weather.place, Canvas::WHITE], [" #{weather.temp.round}C #{weather.words}", Canvas::LIGHT_GREY]]]
          { 'Today' => weather.today, 'Tmrw' => weather.tomorrow }.each do |name, d|
            lines << "  #{name} #{d.low.round}..#{d.high.round}C #{d.words}" if d
          end
          lines
        end

        def rates(rates)
          return [['No rates yet.', Canvas::YELLOW]] unless rates

          [["Forint, ECB #{rates.date}", Canvas::CYAN],
           *rates.huf.map { |c, v| [[c, Canvas::WHITE], [" #{format('%.2f', v)}", Canvas::LIGHT_GREY]] }]
        end

        def quakes(quakes)
          return ['None.'] if quakes.empty?

          now = Time.now.to_i
          quakes.first(4).flat_map do |q|
            place = Layout.wrap(q.place, COLS - 10, 2)
            [[[format('%.1f', q.mag), Canvas::LIGHT_RED], [" #{Layout.age(q.time, now).rjust(3)}", Canvas::GREY],
              ["  #{place.first}", Canvas::LIGHT_GREY]], *place.drop(1).map { |l| "          #{l}" }]
          end
        end

        def ours(ours)
          return [] unless ours

          number, board = ours
          [['Ours today', Canvas::CYAN], [[board.name, Canvas::YELLOW], ["  O, #{number}", Canvas::GREY]], '']
        end

        def note(name, note)
          [[note.heading, Canvas::CYAN], [Layout.plain(note.title)[0, COLS], Canvas::YELLOW],
           *Layout.wrap(Layout.plain(note.text), COLS, 2).map { |l| [l, Canvas::LIGHT_GREY] }, [name, Canvas::GREY], '']
        end

        def board(listing)
          return [] unless listing

          [['Board of the day', Canvas::CYAN], [Layout.plain(listing.title)[0, COLS], Canvas::LIGHT_GREEN],
           [listing.address[0, COLS], Canvas::GREY], '']
        end

        def walls(notes)
          return [] if notes.empty?

          [['On the wall', Canvas::CYAN], *notes.last(2).flat_map do |n|
            [[n['name'].to_s, Canvas::YELLOW], *Layout.wrap(n['text'].to_s, COLS, 2)]
          end]
        end
      end
    end
  end
end
