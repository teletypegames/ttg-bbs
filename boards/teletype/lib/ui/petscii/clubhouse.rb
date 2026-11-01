# frozen_string_literal: true

module UI
  module Petscii
    # The graphics screens of the C64 face: the clubhouse drawn in the
    # uppercase/graphics set on a BBS::Petscii::Canvas (raw PETSCII, the
    # whole screen once, then only what changes), where the menus are the
    # rooms of the club. The reading screens (posts, letters, chat, the
    # Master) stay in the lowercase set of Screen; #text_mode switches back.
    module Clubhouse
      C = BBS::Petscii::Canvas

      # The colour of each part of the board on the C64, the one most like
      # its accent on the modern face (UI::Modern::Accent).
      COLORS = { board: :cyan, messages: :light_green, people: :purple, doors: :orange, you: :light_blue,
                 help: :yellow }.freeze

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
        art.draw_canvas(canvas)
        (1..7).each do |n|
          spot = art.hotspot(:"node_#{n}")
          canvas.text(spot.row, spot.col, ' ' * spot.width, n == node ? :white : :yellow, rvs: true) if scene.lit?(n)
        end
        if scene.inside.positive?
          door = art.hotspot(:door)
          canvas.text(door.row, door.col, '▒' * door.width, :yellow, rvs: true)
        end
        if scene.mail.positive?
          flag = art.hotspot(:flag)
          canvas.text(flag.row, flag.col, ' ', :red, rvs: true)
          box = art.hotspot(:mail)
          canvas.text(box.row, box.col, scene.mail.clamp(0, 99).to_s.center(box.width), :blue, rvs: true)
        end
        spot = art.hotspot(:status)
        canvas.text(spot.row, spot.col, status[0, spot.width].rjust(spot.width), :light_grey)
        art
      end

      # One puff of the chimney's smoke on +canvas+ (+step+ counts them).
      def self.smoke(canvas, art, step)
        spot = art.hotspot(:smoke)
        canvas.clear(spot.row, spot.col, spot.width)
        canvas.text(spot.row, spot.col, SMOKE[step % SMOKE.size][0, spot.width], :light_grey)
      end

      # Asks on the bottom row of the main menu whether the caller leaves;
      # true for Y.
      def self.leave?(screen)
        row = C.new.text(MENU_ROW + 10, 2, 'LEAVE THE CLUBHOUSE?  Y/N', :white)
        screen.session.write_raw(row.span(MENU_ROW + 10, 0, 39) + row.cursor(C::ROWS - 1, 0))
        loop do
          k = screen.key
          k = k.downcase if k.is_a?(String)
          return k == 'y' if ['y', 'n', :escape].include?(k)
        end
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
        def initialize(bbs, session, ctx)
          @bbs     = bbs
          @session = session
          @ctx     = ctx
        end

        def run(lit: nil, unread: 0)
          scene  = @bbs.scene.scene(name, registered: registered?, sysop: sysop?)
          node   = @bbs.online.node(@ctx[:session_id])&.number
          canvas = C.new
          art    = Clubhouse.house(canvas, scene, node: node,
                                                  status: "#{"NODE #{node}  " if node}#{Time.now.strftime('%H:%M')}")
          live(canvas, scene, unread)
          Clubhouse.box(canvas, MENU_ROW - 1, 1, 38, 11, C::DARK_GREY)
          canvas.text(MENU_ROW + 10, 2, HINT, :dark_grey)
          menu = menu(canvas, lit, art, scene.smoking)
          menu.paint
          @session.write_raw(canvas.frame + canvas.cursor(C::ROWS - 1, 0))
          menu.run(drawn: true)
        end

        private

        def name = @ctx[:username] || AccountService::ANONYMOUS
        def registered? = @ctx[:authenticated] == true
        def sysop? = @bbs.sysop?(name, @ctx[:authenticated])

        # Who is calling and what is going on, under the house.
        def live(canvas, scene, unread)
          mail = unread.positive? ? "  #{unread} NEW LETTER#{'S' unless unread == 1}" : ''
          canvas.text(HOUSE_ROWS, 1, "HI #{BBS::Petscii.plain(name).upcase[0, 14]}!", :white)
          inside = "#{scene.inside} INSIDE#{mail}"
          canvas.text(HOUSE_ROWS, 39 - inside.length, inside, unread.positive? ? :light_green : :yellow)
          event = scene.events.first
          return unless event

          days  = ((event.date - Time.now) / 86_400).ceil
          when_ = days <= 0 ? 'TODAY' : "IN #{days} DAY#{'S' unless days == 1}"
          what  = BBS::Petscii.plain(event.name).upcase[0, 38 - 6 - when_.length - 1]
          canvas.text(HOUSE_ROWS + 1, 1, 'NEXT:', :grey)
          canvas.text(HOUSE_ROWS + 1, 7, "#{what} #{when_}", :cyan)
        end

        def menu(canvas, lit, art, smoking)
          items = ROOMS.map do |key, label, section, about|
            BBS::Selector.item(label, key: key, value: key, color: Clubhouse.color(section), about: about)
          end
          index = items.index { |i| i.value == lit }
          puffs = 0
          BBS::Petscii::CanvasMenu.new(@session, items, canvas: canvas, row: MENU_ROW, col: 2, width: 36, columns: 2,
                                                        height: 8, index: index, exits: EXITS, idle: IDLE) do
            next nil unless smoking

            before = canvas.dup
            Clubhouse.smoke(canvas, art, puffs += 1)
            canvas.update(before) + canvas.cursor(C::ROWS - 1, 0)
          end
        end
      end
    end
  end
end
