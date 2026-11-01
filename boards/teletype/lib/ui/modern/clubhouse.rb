# frozen_string_literal: true

module UI
  module Modern
    # The clubhouse pictures of the modern face outside the desktop: the
    # entrance with the guestbook (the logon), the lamps going out (the
    # logoff), the trophy case and the room cards.
    module Clubhouse
      RESET = "\e[0m"
      # The ink of the guestbook and the cream of its pages.
      INK   = "\e[0;38;5;236;48;5;230m"
      PEN   = "\e[0;1;38;5;18;48;5;230m"

      def self.at(row, col) = "\e[#{row};#{col}H"

      # Whether the terminal of +session+ holds a whole picture (80×24).
      def self.fits?(session) = session.term_cols.to_i >= 80 && session.term_rows.to_i >= 24

      # Writes +art+ from the top row of the screen down.
      def self.draw(session, art, top: 1)
        session.write(art.ansi_lines.each_with_index.map { |l, i| "#{at(top + i, 1)}#{l}" }.join + RESET)
      end

      # The entrance of the clubhouse: the door under its lamp, the bell,
      # the coats on the rack (the nodes in use) and the open guestbook, the
      # last guests on its left page, this entry's number, the name and the
      # password on the right. On a terminal under 80×24 the old plain
      # prompt.
      class Entrance
        # The colours of the coats on the rack.
        COATS = [124, 25, 28, 130, 90, 240, 30].freeze

        def initialize(session, bbs)
          @session = session
          @bbs     = bbs
          @art     = Arts.load(:modern, 'entrance')
          @fits    = Clubhouse.fits?(session)
        end

        def show
          number = @bbs.last_callers.caller_number
          return plain(number) unless @fits

          @session.write("\e[0m\e[2J")
          Clubhouse.draw(@session, @art)
          guests
          put(:entry, Formatters.number(number), PEN)
          coats(@bbs.online.count)
          put(:status, "  Teletype BBS · telnet teletypegames.org 2323 · caller ##{Formatters.number(number)} · " \
                       "#{@bbs.online.count} online", "\e[0;38;5;66;48;5;234m")
        end

        # The name, written into the guestbook; nil when the line drops.
        def ask_name = ask(:name, 'Name (blank for Anonymous): ')

        def ask_password = ask(:password, 'Password: ', mask: '*')

        def wrong(text)
          return @session.write("  \e[1;31m#{text}\e[0m\r\n") unless @fits

          put(:password, '', INK)
          spot = @art.hotspot(:status)
          @session.write("#{Clubhouse.at(spot.row + 1, 1)}\e[0;1;38;5;203;48;5;234m  #{text.ljust(spot.width - 2)}\e[0m")
        end

        private

        # The logo and one line, for a terminal under 80×24.
        def plain(number)
          @session.write("\e[0m\e[2J\e[H\r\n")
          Logo.half_blocks.each { |l| @session.write("  #{l}\e[0m\r\n") }
          @session.write("\r\n  Teletype BBS · caller ##{number} · #{@bbs.online.count} online\r\n\r\n")
        end

        # The last three callers on the left page of the guestbook.
        def guests
          @bbs.last_callers.recent(3).each_with_index do |c, i|
            put(:"guest_#{i + 1}", "#{c.username.to_s[0, 10].ljust(11)}#{c.timestamp.to_s[11, 5]}", INK)
          end
        end

        def ask(name, prompt, mask: nil)
          unless @fits
            @session.write("  \e[1;37m#{prompt}\e[0m")
            return @session.readline(mask: mask)
          end

          put(name, '', PEN)
          spot = @art.hotspot(name)
          @session.write("#{Clubhouse.at(spot.row + 1, spot.col + 1)}#{PEN}")
          line = @session.readline(mask: mask)
          @session.write(RESET)
          line
        end

        def put(name, text, sgr)
          spot = @art.hotspot(name)
          @session.write("#{Clubhouse.at(spot.row + 1, spot.col + 1)}#{sgr}#{text[0, spot.width].ljust(spot.width)}#{RESET}")
        end

        # A coat on a hook of the rack for each node in use.
        def coats(count)
          spot = @art.hotspot(:coats)
          count.clamp(0, 7).times do |i|
            col = spot.col + (i * 4)
            sgr = "\e[0;38;5;#{COATS[i]};48;5;233m"
            @session.write("#{Clubhouse.at(spot.row + 1, col + 1)}#{sgr}▐█▌#{Clubhouse.at(spot.row + 2, col + 1)}#{sgr}▀▀▀")
          end
          return unless count > 7

          @session.write("#{Clubhouse.at(spot.row + 1, spot.col + 29)}\e[0;38;5;245;48;5;233m+#{count - 7}#{RESET}")
        end
      end

      # Leaving: the clubhouse from the inside, the lamps going out one by
      # one (the layers leaving_out_1..4), the coat ticket with the length
      # of the call, the thanks, a quote, and the line hanging up.
      module Leaving
        STEP = 0.5

        def self.play(runner, name:, seconds:, caller_number:, quote:)
          session = runner.session
          return plain(runner, seconds, caller_number) unless Clubhouse.fits?(session)

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

        # The goodbye of the rubbs boards, for a terminal under 80×24.
        def self.plain(runner, seconds, caller_number)
          BBS::Goodbye.modern(runner, title: 'the Teletype BBS',
                                      note: "Caller ##{Formatters.number(caller_number)}, " \
                                            "on line for #{Formatters.duration(seconds)}.")
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
      # window of that room is open, by the window's title.
      module Cards
        ROOMS = {
          'Message Boards' => :cork, 'Post to' => :cork, 'Compose' => :cork,
          'Mail' => :mailbox, 'Write a Letter' => :mailbox,
          'Live Chat' => :sofa, 'IRC' => :sofa,
          'Bulletins' => :notice, 'Dev Log' => :workshop,
          'Who is Online' => :guestbook, 'Last Callers' => :guestbook, 'User Listing' => :guestbook,
          'The Team' => :guestbook
        }.freeze
        ABOUT = {
          cork:      'the message boards: General, Tech, Off-Topic, Sysop. Pin a note.',
          mailbox:   'a box for every registered name; the sysop reads the one marked Sysop.',
          sofa:      'sit down and talk: everyone on the lines hears it, C64 callers too.',
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
      # for each of the first three of the top callers, the top posters and
      # the TTG Trivia players, the names on the plates; under the case the
      # places from the fourth on, with a bar each.
      class Trophies < PictureView
        LISTS = %i[callers posters trivia].freeze
        TITLES = { callers: 'TOP CALLERS', posters: 'TOP POSTERS', trivia: 'TTG TRIVIA' }.freeze
        UNITS = { callers: 'calls', posters: 'posts', trivia: 'pts' }.freeze
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
          @art.draw(frame, x: x, y: y)
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
