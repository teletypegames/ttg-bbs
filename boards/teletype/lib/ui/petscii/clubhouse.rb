# frozen_string_literal: true

module UI
  class Petscii
    # The graphics screens of the C64 face: the clubhouse drawn in the
    # uppercase/graphics set on a Rubbs::Petscii::Canvas (raw PETSCII, the
    # whole screen once, then only what changes), where the menus are the
    # rooms of the club. The reading screens (posts, letters, chat, the
    # Master) stay in the lowercase set of Screen; #text_mode switches back.
    module Clubhouse
      C = Rubbs::Petscii::Canvas

      # The colour of each part of the board on the C64, the one most like
      # its accent on the modern face (UI::Modern::Accent).
      COLORS = {
        board:    :cyan,
        messages: :light_green,
        people:   :purple,
        doors:    :orange,
        you:      :light_blue,
        help:     :yellow
      }.freeze

      # The rooms of the main menu, down the left column, then the right:
      # the key (the old menu's, so Board's actions stay), the name of the
      # room, its part of the board and the line about it.
      ROOMS = [
        ['m', 'CORK BOARD', :messages, 'READ AND POST ON THE CORK BOARD'],
        ['e', 'MAILBOX', :messages, 'YOUR LETTERS; WRITE TO THE SYSOP'],
        ['o', 'GRAFFITI WALL', :messages, 'A LINE ON THE WALL FOR EVERY CALLER'],
        ['l', 'SOFA CHAT', :messages, 'TALK WITH WHOEVER IS ON LINE'],
        ['i', 'RADIO (IRC)', :messages, 'THE IRC CHANNEL, READ ONLY'],
        ['p', 'RING THE BELL', :messages, 'CALL THE SYSOP TO A CHAT'],
        ['u', 'NOTICE BOARD', :board, 'BULLETINS: RULES, EVENTS, NEWCOMERS'],
        ['d', 'WORKSHOP', :board, 'WHAT WE ARE MAKING DOWN THERE'],
        ['c', 'GUESTBOOK', :people, 'WHO IS INSIDE, WHO CALLED, THE TEAM'],
        ['h', 'TROPHIES', :people, 'THE TOP CALLERS, POSTERS, PLAYERS'],
        ['v', 'BALLOT BOX', :people, 'THE POLLS OF THE BOARD'],
        ['s', 'YOU', :you, 'YOUR STATS, PROFILE AND NAME'],
        ['r', 'GAMES ROOM', :doors, 'C64, PLUS/4 AND THE OTHER DOORS'],
        ['n', 'TOWN MAP', :board, 'THE OTHER BOARDS: GAMES, WIKI, BLOG'],
        ['t', 'ASK THE BAR', :help, 'THE TTG MASTER KNOWS WHERE THINGS ARE'],
        ['q', 'LEAVE', :help, 'HANG UP. SEE YOU ON THE WIRE!']
      ].freeze
      # Keys the menu takes besides the rooms: the system info, the help,
      # the sysop console, a log off, and the text menu (for a terminal that
      # cannot show the graphics, such as UltimateTerm in its ANSI mode).
      EXITS = { 'y' => 'y', '?' => '?', 'z' => 'z', 'x' => 'q', '*' => '*' }.freeze
      HINT  = 'CRSR RETURN  ?:HELP  Y:INFO  *:TEXT'

      # The rows of the screen: the house, the two live lines, the menu box.
      HOUSE_ROWS = 10
      MENU_ROW   = 13
      # Seconds between two puffs of smoke while the caller thinks.
      IDLE = 1.0
      # The smoke from the chimney, a frame a puff.
      SMOKE = ['▒ ▒  ', ' ▒ ▒ ', '  ▒ ▒', ' ▒  ▒'].freeze

      def self.color(section) = C.color(COLORS.fetch(section))

      # Back to the reading screens: the lowercase set, reverse off, and the
      # session's encoder told the colour (it cannot know what the raw
      # bytes left), so its next colour goes out.
      def self.text_mode(session)
        session.write_raw([C::LOWERCASE, C::RVS_OFF].pack('C*'))
        session.write("\e[1;30m\e[0m")
      end

      # The clubhouse at the top of a canvas: the house of +scene+'s time of
      # day with its season's layers, lit from +scene+ (a SceneModel) for
      # the caller on node +node+, and +status+ in the top row.
      def self.house(canvas, scene, node:, status:)
        art = Arts.house(:c64, scene.season)
        Rubbs::Petscii::Art.draw(art, canvas)
        (1..7).each { |n| at(canvas, art, :"node_#{n}", '', n == node ? :white : :yellow) if scene.lit?(n) }
        at(canvas, art, :door, '▒' * art.hotspot(:door).width, :yellow) if scene.inside.positive?
        mailbox(canvas, art, scene.mail) if scene.mail.positive?
        spot = art.hotspot(:status)
        canvas.text(spot.row, spot.col, status[0, spot.width].rjust(spot.width), :light_grey)
        art
      end

      # +text+ reversed in +color+, over the whole hotspot +name+ of +art+.
      def self.at(canvas, art, name, text, color)
        spot = art.hotspot(name)
        canvas.text(spot.row, spot.col, text.center(spot.width), color, rvs: true)
      end

      # The flag up and the count of the letters on the mailbox.
      def self.mailbox(canvas, art, mail)
        flag = art.hotspot(:flag)
        canvas.text(flag.row, flag.col, ' ', :red, rvs: true)
        at(canvas, art, :mail, mail.clamp(0, 99).to_s, :blue)
      end

      # One puff of the chimney's smoke on +canvas+ (+step+ counts them).
      def self.smoke(canvas, art, step)
        spot = art.hotspot(:smoke)
        canvas.clear(spot.row, spot.col, spot.width)
        canvas.text(spot.row, spot.col, SMOKE[step % SMOKE.size][0, spot.width], :light_grey)
      end

      # Asks on the bottom row of the main menu whether the caller leaves;
      # true for Y.
      def self.leave?(face)
        row = C.new.text(MENU_ROW + 10, 2, 'LEAVE THE CLUBHOUSE?  Y/N', :white)
        face.session.write_raw(row.span(MENU_ROW + 10, 0, 39) + row.cursor(C::ROWS - 1, 0))
        loop do
          k = face.key
          k = k.downcase if k.is_a?(String)
          return k == 'y' if ['y', 'n', :escape].include?(k)
        end
      end

      # The bytes that turn +before+ into +canvas+: the rows where much
      # changed (a line of text) as spans, the scattered cells as a patch,
      # or the whole frame when that is less.
      def self.changes(canvas, before)
        changed = canvas.changes(before)
        return ''.b if changed.empty?

        wide  = changed.group_by(&:first).select { |_, cells| cells.size > 6 }.keys
        spans = wide.map { |row| canvas.span(row, 0, C::COLS - 1) }.join.b
        mixed = spans + canvas.patch(changed.reject { |pos| wide.include?(pos.first) })
        [mixed, canvas.update(before)].min_by(&:bytesize)
      end

      # A rounded box of +color+ from +row+, +col+, +width+ × +height+.
      def self.box(canvas, row, col, width, height, color)
        canvas.text(row, col, "╭#{'─' * (width - 2)}╮", color)
        (1..(height - 2)).each do |i|
          canvas.text(row + i, col, '│', color)
          canvas.text(row + i, col + width - 1, '│', color)
        end
        canvas.text(row + height - 1, col, "╰#{'─' * (width - 2)}╯", color)
      end

      # The main menu of a call: the house, the caller and what is going
      # on, and the rooms as a cursor menu. The key of the room taken (or of
      # an EXITS key); nil for ← or RUN/STOP.
      class MainMenu
        # The menu of +name+'s call on +session+, the house lit from +scene+
        # (a SceneModel), their own window that of +node+.
        def initialize(session, scene, node:, name:)
          @session = session
          @scene   = scene
          @node    = node
          @name    = name
        end

        def run(lit: nil, unread: 0)
          scene  = @scene
          canvas = C.new
          art    = Clubhouse.house(
            canvas,
            scene,
            node:   @node,
            status: "#{"NODE #{@node}  " if @node}#{Time.now.strftime('%H:%M')}"
          )
          live(canvas, scene, unread)
          Clubhouse.box(canvas, MENU_ROW - 1, 1, 38, 11, C::DARK_GREY)
          canvas.text(MENU_ROW + 10, 2, HINT, :dark_grey)
          menu = menu(canvas, lit, art, scene.smoking)
          menu.paint
          @session.write_raw(canvas.frame + canvas.cursor(C::ROWS - 1, 0))
          menu.run(drawn: true)
        end

        private

        # Who is calling and what is going on, under the house.
        def live(canvas, scene, unread)
          mail = unread.positive? ? "  #{unread} NEW LETTER#{'S' unless unread == 1}" : ''
          canvas.text(HOUSE_ROWS, 1, "HI #{Rubbs::Petscii.plain(@name).upcase[0, 14]}!", :white)
          inside = "#{scene.inside} INSIDE#{mail}"
          canvas.text(HOUSE_ROWS, 39 - inside.length, inside, unread.positive? ? :light_green : :yellow)
          next_event(canvas, scene.events.first) if scene.events.first
        end

        def next_event(canvas, event)
          days  = ((event.date - Time.now) / 86_400).ceil
          when_ = days <= 0 ? 'TODAY' : "IN #{days} DAY#{'S' unless days == 1}"
          what  = Rubbs::Petscii.plain(event.name).upcase[0, 38 - 6 - when_.length - 1]
          canvas.text(HOUSE_ROWS + 1, 1, 'NEXT:', :grey)
          canvas.text(HOUSE_ROWS + 1, 7, "#{what} #{when_}", :cyan)
        end

        def menu(canvas, lit, art, smoking)
          items = ROOMS.map do |key, label, section, about|
            Rubbs::Common::Screens::Selector.item(label, key: key, value: key, color: Clubhouse.color(section), about: about)
          end
          index = items.index { |i| i.value == lit }
          puffs = 0
          Rubbs::Petscii::CanvasMenu.new(
            @session,
            items,
            canvas:  canvas,
            row:     MENU_ROW,
            col:     2,
            width:   36,
            columns: 2,
            height:  8,
            index:   index,
            exits:   EXITS,
            idle:    IDLE
          ) do
            next nil unless smoking

            before = canvas.dup
            Clubhouse.smoke(canvas, art, puffs += 1)
            canvas.update(before) + canvas.cursor(C::ROWS - 1, 0)
          end
        end
      end

      # A picture with places on it to walk between with CRSR: the whole
      # screen goes out once, then each move as a patch of what changed.
      # A subclass gives #places, #at (the [row, col] of a place, for the
      # cursor keys), #paint (the whole picture), #mark (a place chosen or
      # not) and #info (the rows about the chosen one).
      class Picture
        MOVES = { left: [0, -1], right: [0, 1], up: [-1, 0], down: [1, 0] }.freeze
        BACK  = [:escape, '←', 'q'].freeze

        def initialize(session)
          @session = session
          @index   = 0
        end

        def chosen = places[@index]

        # Shows the picture and walks it until RETURN (the chosen place) or
        # ← / RUN/STOP / Q (nil).
        def run
          @canvas = C.new
          paint
          places.each { |p| mark(p, p.equal?(chosen)) }
          info
          @session.write_raw(@canvas.frame + rest)
          walk
        end

        # The bytes of the last move (for measuring).
        attr_reader :last

        private

        def rest = @canvas.cursor(C::ROWS - 1, 0)

        def walk
          loop do
            key = @session.readkey
            raise Rubbs::Common::Line::Hangup if key.nil?

            key = key.downcase if key.is_a?(String)
            return nil if BACK.include?(key)
            return chosen if key == :enter

            move(*MOVES[key]) if MOVES.key?(key)
          end
        end

        # To the place nearest in the direction +dr+, +dc+: the cross
        # distance weighs more, so a row stays a row.
        def move(dr, dc)
          from = at(chosen)
          best = places.each_index.select { |i| ahead?(at(places[i]), from, dr, dc) }
            .min_by { |i| distance(at(places[i]), from, dr) }
          return unless best && best != @index

          show_move(best)
        end

        def ahead?((r, c), (r0, c0), dr, dc) = dr.zero? ? ((c - c0) * dc).positive? : ((r - r0) * dr).positive?

        def distance((r, c), (r0, c0), dr) = dr.zero? ? (c - c0).abs + ((r - r0).abs * 8) : (r - r0).abs + ((c - c0).abs * 3)

        # The marks and the info moved to place +index+, as a patch.
        def show_move(index)
          before = @canvas.dup
          mark(chosen, false)
          @index = index
          mark(chosen, true)
          info
          @last = Clubhouse.changes(@canvas, before) + rest
          @session.write_raw(@last)
        end

        def line(row, text, color, col: 1)
          @canvas.clear(row, 0, C::COLS)
          @canvas.text(row, col, text[0, C::COLS - col - 1], color)
        end
      end

      # The town map on the C64 (N): the town (art town.yml) with each board
      # a 3×3 building in its colour where lib/content/network.yml puts it,
      # its short name under it; the chosen one's name reversed, and under
      # the map its name, two words about it and its port.
      class TownMap < Picture
        TOP = 1

        def initialize(session, network)
          super(session)
          @boards = network.boards
        end

        def places = @boards

        private

        def at(board) = board.place.fetch(:c64).reverse

        def paint
          @canvas.text(0, 1, 'TOWN MAP', :cyan)
          @canvas.text(0, 10, '- THE BBS NETWORK', :dark_grey)
          Rubbs::Petscii::Art.draw(Arts.load(:c64, 'town'), @canvas, row: TOP)
          @boards.each { |b| Rubbs::Petscii::Art.draw(Arts.load(:c64, "building_#{b.id}"), @canvas, row: TOP + at(b)[0], col: at(b)[1]) }
          @canvas.text(24, 1, 'CRSR: WALK   RETURN OR <-: BACK', :dark_grey)
        end

        def mark(board, lit)
          row, col = at(board)
          text = board.short.center(9)
          @canvas.text(TOP + row + 3, col - 3, text, board.c64, rvs: lit)
        end

        def info
          b = chosen
          line(22, b.name.upcase, b.c64)
          line(23, "#{b.words} - TELETYPEGAMES.ORG #{b.port}", :light_grey)
        end
      end

      # The games room on the C64 (R): five stations (art games_room.yml), a
      # lamp over each burning while somebody is inside, the chosen one's
      # screen on and its name reversed. RETURN opens the C64 and the
      # Plus/4; the others wait on the modern face.
      class GamesRoom < Picture
        TOP = 2
        # The names under the stations.
        LABELS = { sermo: 'SERMO', c64: 'C64', plus4: 'PLUS/4', ra: 'RA', trivia: 'TRIVIA' }.freeze
        # What a station's screen shows when it is chosen, and when not:
        # [text, colour] each.
        SCREENS = {
          sermo:  [['SERMO', :green], ['', :green]],
          c64:    [['READY', :light_blue], ['', :blue]],
          plus4:  [['READY', :white], ['', :grey]],
          ra:     [['●', :yellow], ['●', :brown]],
          trivia: [['ABCD?', :yellow], ['?????', :purple]]
        }.freeze

        def initialize(session, doors, scene)
          super(session)
          @doors = doors
          @scene = scene
          @art   = Arts.load(:c64, 'games_room')
        end

        def places = @doors

        # Like Picture#run, but RETURN on a door the C64 cannot show tells so
        # and stays.
        def run
          loop do
            door = super
            return door if door.nil? || door.c64?

            line(21, 'MODERN FACE ONLY: CALL WITH A PC', :light_red)
            @session.write_raw(@canvas.span(21, 0, C::COLS - 1) + rest)
            @session.readkey
          end
        end

        private

        def spot(name, door) = @art.hotspot(:"#{name}_#{door.name}")

        def at(door) = [0, spot(:label, door).col]

        def paint
          @canvas.text(0, 1, 'GAMES ROOM', :orange)
          @canvas.text(0, 12, '- STEP UP TO A STATION', :dark_grey)
          Rubbs::Petscii::Art.draw(@art, @canvas, row: TOP)
          @doors.each do |door|
            lamp(door)
            label = spot(:label, door)
            @canvas.text(TOP + label.row + 1, label.col, 'PC ONLY'.center(label.width), :dark_grey) unless door.c64?
          end
          @canvas.text(23, 1, 'CRSR: CHOOSE  RETURN: STEP IN  <-: BACK', :dark_grey)
        end

        def lamp(door)
          n = @scene.in_door(door.title)
          return unless n.positive?

          lamp = spot(:lamp, door)
          @canvas.text(TOP + lamp.row, lamp.col, '◢█◣', :yellow)
          count = spot(:count, door)
          @canvas.text(TOP + count.row, count.col, n.clamp(0, 99).to_s, :white)
        end

        def mark(door, lit)
          label = spot(:label, door)
          @canvas.text(TOP + label.row, label.col, LABELS.fetch(door.name).center(label.width), :orange, rvs: lit)
          screen = spot(:screen, door)
          text, color = SCREENS.fetch(door.name)[lit ? 0 : 1]
          @canvas.text(TOP + screen.row, screen.col, text.ljust(screen.width)[0, screen.width], color)
        end

        def info
          door = chosen
          n = @scene.in_door(door.title)
          line(15, door.title.upcase, :orange)
          words = Rubbs::Modern::FrameBuffer.wrap_ansi(Rubbs::Petscii.plain(door.about.to_s).upcase, 37).first(4)
          (16..19).each_with_index { |row, i| line(row, words[i].to_s, :light_grey) }
          line(20, n.zero? ? 'NOBODY INSIDE' : "#{n} INSIDE", :grey)
          line(21, door.c64? ? 'RETURN: STEP IN' : 'ON THE MODERN FACE ONLY', door.c64? ? :yellow : :dark_grey)
        end
      end

      # The trophy case on the C64 (H): a cup for the top caller, the top
      # poster and the best TTG Trivia player, their names under the cups,
      # and the places after them in three columns.
      module Trophies
        TITLES = { callers: 'CALLERS', posters: 'POSTERS', trivia: 'TRIVIA' }.freeze

        def self.show(session, fame)
          art = Arts.load(:c64, 'trophies')
          canvas = C.new
          canvas.text(0, 1, 'TROPHIES', :purple)
          canvas.text(0, 10, '- THE HALL OF FAME', :dark_grey)
          Rubbs::Petscii::Art.draw(art, canvas, row: 2)
          TITLES.each_with_index { |(list, title), i| compartment(canvas, art, list, title, fame.fetch(list), i) }
          canvas.text(23, 1, 'RETURN OR <-: BACK', :dark_grey)
          session.write_raw(canvas.frame + canvas.cursor(C::ROWS - 1, 0))
          session.readkey
        end

        # One cup: its title and the first name on its plate, the places
        # after it in column +column+ under the case.
        def self.compartment(canvas, art, list, title, rows, column)
          label(canvas, art.hotspot(:"title_#{list}"), title, :white)
          plate = art.hotspot(:"plate_#{list}")
          label(canvas, plate, rows.first ? upper(rows.first.first)[0, plate.width] : '-', :yellow)
          places(canvas, rows.drop(1).first(6), 1 + (column * 13))
        end

        def self.places(canvas, rows, col)
          rows.each_with_index do |(name, n), j|
            line = "#{j + 2} #{upper(name)[0, 6].ljust(6)}#{n.to_s.rjust(3)}"
            canvas.text(12 + j, col, line[0, 12], j.zero? ? :light_grey : :grey)
          end
        end

        def self.label(canvas, spot, text, color) = canvas.text(2 + spot.row, spot.col, text.center(spot.width), color)

        def self.upper(name) = Rubbs::Petscii.plain(name).upcase
      end

      # The card of a room, once a call before the room opens: its picture,
      # its name and what it is; any key goes on.
      module Cards
        ABOUT = {
          cork:      'THE MESSAGE BOARDS: GENERAL, TECH, OFF-TOPIC, SYSOP',
          mailbox:   'YOUR LETTERS, AND A BOX FOR THE SYSOP',
          sofa:      'SIT DOWN AND TALK WITH WHOEVER IS IN',
          notice:    'THE RULES, WHAT IS COMING UP, THE NETWORK',
          workshop:  'WHAT THE TEAM MAKES DOWN THERE',
          guestbook: 'WHO IS INSIDE, WHO CALLED, WHO YOU ARE'
        }.freeze
        # The card of each key of the main menu that opens a reading room.
        KEYS = {
          'm' => :cork,
          'e' => :mailbox,
          'l' => :sofa,
          'u' => :notice,
          'd' => :workshop,
          'c' => :guestbook,
          's' => :guestbook
        }.freeze
        TOP = 8

        # Shows the card of +room+ unless +seen+ (a Set) has it, and adds it.
        def self.show(session, room, seen)
          return if room.nil? || seen.include?(room)

          seen << room
          art = Arts.load(:c64, "card_#{room}")
          canvas = Rubbs::Petscii::Art.draw(art, C.new, row: TOP)
          about(canvas, art, room)
          hint = art.hotspot(:hint)
          canvas.text(TOP + hint.row, hint.col, 'RETURN: GO IN', :dark_grey)
          session.write_raw(canvas.frame + canvas.cursor(C::ROWS - 1, 0))
          session.readkey
        end

        def self.about(canvas, art, room)
          about = art.hotspot(:about)
          Rubbs::Modern::FrameBuffer.wrap_ansi(ABOUT.fetch(room), about.width).first(about.height).each_with_index do |l, i|
            canvas.text(TOP + about.row + i, about.col, l, :light_grey)
          end
        end
      end

      # Leaving on the C64: the room from the inside, the coat ticket, the
      # thanks and a quote; then the four lamps go out one by one (a patch
      # each), and the line hangs up.
      module Leaving
        TOP  = 2
        STEP = 0.6

        def self.play(session, name:, seconds:, caller_number:, quote:)
          canvas = C.new
          canvas.text(0, 1, 'LEAVING THE CLUBHOUSE', :light_green)
          room(canvas, [], caller_number, seconds)
          thanks(canvas, name, quote)
          session.write_raw(canvas.frame + canvas.cursor(C::ROWS - 1, 0))
          steps = (1..4).map { |n| lamp_out(session, canvas, n, caller_number, seconds) }
          sleep STEP
          canvas.text(22, 1, '+++  ATH0', :grey)
          canvas.text(22, 12, 'NO CARRIER', :light_red)
          session.write_raw(canvas.span(22, 0, 22) + canvas.cursor(C::ROWS - 1, 0))
          steps
        end

        def self.thanks(canvas, name, quote)
          canvas.text(TOP + 14, 1, "THANKS FOR CALLING, #{Rubbs::Petscii.plain(name).upcase[0, 16]}!", :white)
          text, who = quote
          words = Rubbs::Modern::FrameBuffer.wrap_ansi(Rubbs::Petscii.plain("\"#{text}\"#{" - #{who}" if who}").upcase, 38)
          words.first(3).each_with_index { |l, i| canvas.text(TOP + 16 + i, 1, l, :grey) }
        end

        # Lamp +n+ goes out, as a patch; returns its bytes.
        def self.lamp_out(session, canvas, n, caller_number, seconds)
          sleep STEP
          before = canvas.dup
          room(canvas, (1..n).map { |i| "leaving_out_#{i}" }, caller_number, seconds)
          bytes = canvas.update(before)
          session.write_raw(bytes)
          bytes.bytesize
        end

        def self.room(canvas, layers, caller_number, seconds)
          art = Arts.load(:c64, 'leaving', layers)
          Rubbs::Petscii::Art.draw(art, canvas, row: TOP)
          spot = art.hotspot(:ticket)
          minutes = (seconds / 60).to_i
          on = minutes.positive? ? "#{minutes}M" : "#{seconds.to_i}S"
          canvas.text(TOP + spot.row, spot.col, "COAT CHECK NO. #{caller_number}  -  ON LINE #{on}", :yellow)
        end
      end
    end
  end
end
