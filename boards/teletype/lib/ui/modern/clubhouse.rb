# frozen_string_literal: true

module UI
  module Modern
    # The clubhouse pictures of the modern face outside the desktop: the
    # lamps going out (the logoff), the trophy case and the room cards.
    module Clubhouse
      RESET = "\e[0m"

      def self.at(row, col) = "\e[#{row};#{col}H"

      # Whether the terminal of +session+ holds a whole picture (80×24).
      def self.fits?(session) = session.term_cols.to_i >= 80 && session.term_rows.to_i >= 24

      # Writes +art+ from the top row of the screen down.
      def self.draw(session, art, top: 1)
        session.write(Rubbs::Modern::Art.lines(art).each_with_index.map { |l, i| "#{at(top + i, 1)}#{l}" }.join + RESET)
      end

      # Leaving: the clubhouse from the inside, the lamps going out one by
      # one (the layers leaving_out_1..4), the coat ticket with the length
      # of the call, the thanks, a quote, and the line hanging up. On a
      # terminal under 80×24 the goodbye of the rubbs boards.
      module Leaving
        STEP = 0.5

        def self.play(runner, bbs)
          context = runner.context
          seconds = Time.now - (context[:call_started] || Time.now)
          number  = context[:caller_number] || bbs.last_callers.caller_number
          return plain(runner.session, seconds, number) unless Clubhouse.fits?(runner.session)

          lamps_out(runner.session, runner.session.identity.name || MemberService::ANONYMOUS, seconds, number, bbs.taglines.pick)
        end

        def self.lamps_out(session, name, seconds, caller_number, quote)
          session.write("\e[0m\e[2J")
          frame(session, [], caller_number, seconds)
          thanks(session, name, quote)
          (1..4).each do |n|
            sleep STEP
            frame(session, (1..n).map { |i| "leaving_out_#{i}" }, caller_number, seconds)
          end
          sleep 0.8
          session.write("#{Clubhouse.at(22, 3)}\e[0;37m+++   ATH0   \e[1;31mNO CARRIER\e[0m\r\n\r\n")
        end

        def self.plain(session, seconds, caller_number)
          Rubbs::Modern::Goodbye.show(
            session,
            title: 'the Teletype BBS',
            note:  "Caller ##{Formatters.number(caller_number)}, " \
                   "on line for #{Formatters.duration(seconds)}."
          )
        end

        # The thanks, the quote and where to find us, under the picture.
        def self.thanks(session, name, quote, y = 16)
          session.write("#{Clubhouse.at(y, 3)}\e[1;37mThanks for calling the Teletype BBS, \e[1;33m#{name}\e[1;37m!\e[0m")
          Formatters.wrap(Formatters::Taglines.line(quote), 72).first(2).each_with_index do |l, i|
            session.write("#{Clubhouse.at(y + 1 + i, 3)}\e[1;30m...\e[0;37m#{l}\e[0m")
          end
          session.write("#{Clubhouse.at(y + 4, 3)}\e[0;37mOur games: \e[1;36mteletypegames.org\e[0;37m · every " \
                        "board: \e[1;36mtelnet teletypegames.org 2399\e[0m")
        end

        def self.frame(session, layers, caller_number, seconds)
          art = Arts.load(:modern, 'leaving', layers)
          Clubhouse.draw(session, art, top: 1)
          spot = art.hotspot(:ticket)
          sgr = "\e[0;38;5;236;48;5;223m"
          ['COAT CHECK', "No. #{caller_number}", "on #{Formatters.duration(seconds)}"].each_with_index do |t, i|
            session.write("#{Clubhouse.at(spot.row + 1 + i, spot.col + 1)}#{sgr}#{t.center(spot.width)}#{RESET}")
          end
        end
      end

      # The room cards: the vignette at the top of the desktop while a
      # window of that room is open, by the window's title. The cork board
      # and the mailbox open on the whole screen (TTG::Wall, TTG::Feedback),
      # so their cards wait for a window of theirs.
      module Cards
        ROOMS = {
          'Bulletins'     => :notice,
          'Dev Log'       => :workshop,
          'Who is Online' => :guestbook,
          'Last Callers'  => :guestbook,
          'User Listing'  => :guestbook,
          'The Team'      => :guestbook
        }.freeze
        ABOUT = {
          cork:      'the wall of the clubhouse: pin a note, answer one. C64 callers read it too.',
          mailbox:   'a letter to the sysop: feedback, a bug, an idea. They read every one.',
          notice:    'the bulletins by the door: the rules, what is coming up, the network.',
          workshop:  'what the team makes down there, push by push, on git.teletypegames.org.',
          guestbook: 'who is inside, who called, who signed it: the callers of the clubhouse.'
        }.freeze

        # The room of the window titled +title+ (without its icon), or nil.
        def self.room(title)
          ROOMS.find { |prefix, _| title.to_s.start_with?(prefix) }&.last
        end
      end

      # The trophy case (People > Hall of Fame): three compartments, a cup
      # for each of the first three of the top callers, the names most on
      # the wall and the TTG Trivia players, the names on the plates; under
      # the case the places from the fourth on, with a bar each.
      class Trophies < PictureView
        LISTS = %i[callers wall trivia].freeze
        TITLES = { callers: 'TOP CALLERS', wall: 'MOST ON THE WALL', trivia: 'TTG TRIVIA' }.freeze
        UNITS = { callers: 'calls', wall: 'notes', trivia: 'pts' }.freeze
        INK = "\e[0;1;38;5;16;48;5;178m"

        def initialize(fame:, **kw)
          super(**kw)
          @fame = fame
          @art  = Arts.load(:modern, 'trophies')
        end

        def places = []
        def width = @art.cols
        def height = @art.rows + 7
        def handle_event(_event) = nil

        private

        def draw(frame, x, y)
          Rubbs::Modern::Art.draw(@art, frame, x: x, y: y)
          LISTS.each_with_index do |list, i|
            rows = @fame.fetch(list)
            compartment(frame, x, y, list, rows)
            rest(frame, x + (i * 25) + 1, y + @art.rows + 1, rows.drop(3), list)
          end
          write(frame, x, y + height - 1, 'Esc: back to the clubhouse'.ljust(width), "\e[0;38;5;66m")
        end

        # One compartment of the case: its title, the first three on the
        # plates and the score of the first.
        def compartment(frame, x, y, list, rows)
          label(frame, x, y, :"title_#{list}", TITLES[list], "\e[0;1;38;5;230;48;5;236m")
          (1..3).each do |place|
            name, = rows[place - 1]
            spot = :"plate_#{list}_#{place}"
            label(frame, x, y, spot, (name || '-').to_s[0, @art.hotspot(spot).width], INK)
          end
          first = rows.first ? "#{rows.first.last} #{UNITS[list]}" : ''
          label(frame, x, y, :"score_#{list}_1", first, "\e[0;38;5;230;48;5;94m")
        end

        # +text+ centred on the hotspot +name+ of the case at +x+, +y+.
        def label(frame, x, y, name, text, sgr)
          spot = @art.hotspot(name)
          write(frame, x + spot.col, y + spot.row, text.center(spot.width), sgr)
        end

        # The fourth place on, a bar each fading from gold to brown.
        def rest(frame, x, y, rows, list)
          return write(frame, x, y, '(nobody else yet)', "\e[0;38;5;240m") if rows.empty?

          max = rows.first.last.to_f
          rows.first(5).each_with_index { |row, i| place(frame, x, y + i, i, row, max) }
          list
        end

        # The place +index+ (from the fourth) of a [name, count] +row+.
        def place(frame, x, y, index, row, max)
          name, count = row
          bar = max.positive? ? (count / max * 6).round.clamp(1, 6) : 1
          color = "\e[0;38;5;#{[220, 214, 178, 172, 136][index]}m"
          write(frame, x, y, "#{index + 4}. #{name.to_s[0, 10].ljust(10)}", "\e[0;38;5;252m")
          write(frame, x + 14, y, '▆' * bar, color)
          write(frame, x + 20, y, count.to_s.rjust(4), color)
        end
      end
    end
  end
end
