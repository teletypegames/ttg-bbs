# frozen_string_literal: true

module UI
  module Modern
    # A room of the clubhouse as a window: a picture (Rubbs::Common::Art) with places
    # on it to choose with the arrows or the mouse, and a few lines about
    # the chosen one under it. The town map and the games room.
    class PictureWindow < Rubbs::Modern::Window
      # Opens +view+ (a PictureView) in a window titled +title+, in the
      # colour and with the sign of its +section+ of the board, in the
      # middle of +app+.
      def self.open(app, view, title:, section:)
        window = new(title: Icon.title(section, title), maximizable: false)
        window.accent = Accent::STYLES.fetch(section)
        window.centre_on(app, view)
        app.open_window(window)
        window.reset_focus
        window
      end

      # The window in the middle of +app+, +view+ inside it.
      def centre_on(app, view)
        width  = view.width + 4
        height = view.height + 2
        layout(((app.cols - width) / 2) + 1, [((app.rows - height) / 2) + 1, 2].max, width, height)
        view.layout(bounds.x + 2, bounds.y + 1, view.width, view.height)
        add(view)
      end
    end

    # The picture and its places. A subclass gives #places (anything), the
    # #width and #height it draws in, #draw and #activate.
    class PictureView < Rubbs::Modern::Widgets::Widget
      MOVES = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }.freeze

      def initialize(**kw)
        super
        @index = 0
      end

      def focusable? = true

      def chosen = places[@index]

      def render(frame) = draw(frame, bounds.x, bounds.y)

      def handle_event(event)
        if event.mouse? && event.mouse.kind == :press
          hit = places.index { |p| inside?(p, event.x - bounds.x, event.y - bounds.y) }
          return nil unless hit

          @index = hit
          return :handled
        end
        return nil unless event.key?
        return activate if event.key == :enter
        return step(*MOVES[event.key]) if MOVES.key?(event.key)

        nil
      end

      private

      # The place nearest in the direction +dx+, +dy+, by where the places
      # are (#at): the cross distance weighs more, so a row stays a row.
      def step(dx, dy)
        from = at(chosen)
        best = places.each_index.select { |i| ahead?(at(places[i]), from, dx, dy) }
          .min_by { |i| distance(at(places[i]), from, dx) }
        @index = best if best
        :handled
      end

      def ahead?((x, y), (x0, y0), dx, dy) = dx.zero? ? ((y - y0) * dy).positive? : ((x - x0) * dx).positive?

      def distance((x, y), (x0, y0), dx)
        dx.zero? ? ((y - y0).abs * 1) + ((x - x0).abs * 3) : ((x - x0).abs * 1) + ((y - y0).abs * 8)
      end

      def write(frame, x, y, text, sgr)
        frame.move(x, y)
        frame.write(text, sgr: sgr)
      end
    end

    # The town map on the clubhouse wall (Board > BBS Network): the town
    # (art town.yml), each board of the network a building
    # (building_<id>.yml) where lib/content/network.yml puts it, with its
    # name under it in its accent. The chosen one's name lights up, and
    # under the map what it carries and how to walk over. On a screen
    # shorter than the town it shows +rows+ of it, scrolled so that the
    # chosen building and its name are in sight.
    class TownMap < PictureView
      LABEL = 18
      # A building and its name, in rows.
      PLOT = 5
      # The lines about the chosen board under the map.
      INFO = 4

      def initialize(network:, rows: nil, **kw)
        super(**kw)
        @boards = network.boards
        @town   = Arts.load(:modern, 'town')
        @icons  = @boards.to_h { |b| [b.id, Arts.load(:modern, "building_#{b.id}")] }
        @shown  = (rows ? rows - INFO : @town.rows).clamp(PLOT, @town.rows)
        @scroll = 0
      end

      def places = @boards
      def width = @town.cols
      def height = @shown + INFO
      def activate = :handled

      private

      def at(board) = board.place.fetch(:modern)

      def inside?(board, x, y)
        bx, by = at(board)
        x.between?(bx - 3, bx + LABEL - 4) && (y + @scroll).between?(by, by + 4)
      end

      # The rows scrolled away so the chosen building's plot is in sight.
      def follow
        top = at(chosen)[1]
        @scroll = @scroll.clamp(top + PLOT - @shown, top).clamp(0, @town.rows - @shown)
      end

      def draw(frame, x, y)
        follow
        frame.clip(x, y, width, @shown) { draw_town(frame, x, y - @scroll) }
        info(frame, x, y + @shown)
      end

      def draw_town(frame, x, y)
        @town.draw(frame, x: x, y: y)
        @boards.each do |b|
          bx, by = at(b)
          @icons[b.id].draw(frame, x: x + bx, y: y + by)
          color = Rubbs::Common::Art.color(b.accent).ansi
          sgr = b.equal?(chosen) ? "\e[0;1;38;5;16;48;5;#{color}m" : "\e[0;38;5;#{color}m"
          write(frame, x + bx - 3, y + by + 4, b.name.center(LABEL), sgr)
        end
      end

      def info(frame, x, y)
        b     = chosen
        color = Rubbs::Common::Art.color(b.accent).ansi
        write(frame, x, y, "#{b.name} · #{b.building}".ljust(width), "\e[0;1;38;5;#{color}m")
        write(frame, x, y + 1, b.about.ljust(width), "\e[0;38;5;252m")
        write(
          frame,
          x,
          y + 2,
          "walk over: from TTG Gate BBS (2399), or telnet #{b.address.sub(':', ' ')}".ljust(width),
          "\e[0;38;5;116m"
        )
        write(frame, x, y + 3, '←↑↓→ or a click: another building · Esc: back to the clubhouse'.ljust(width), "\e[0;38;5;66m")
      end
    end

    # The games room at the back (Doors): five stations, a lamp over each
    # that burns while somebody is inside (with the count), the chosen one's
    # screen switched on and its name lit; Enter steps in.
    class GamesRoom < PictureView
      LIT    = "\e[0;1;38;5;226;48;5;235m"
      GLOW   = "\e[0;38;5;222;48;5;235m"
      # What the chosen station shows on its screen.
      SCREENS = {
        sermo:  ["\e[0;38;5;46;48;5;22m", ['SERMO>_', ' ready ']],
        c64:    ["\e[0;38;5;117;48;5;19m", [' READY. ', ' █       '.rstrip.ljust(9)]],
        plus4:  ["\e[0;38;5;16;48;5;250m", [' READY. ', ' █       '.rstrip.ljust(9)]],
        ra:     ["\e[0;1;38;5;226;48;5;235m", ['◄☼►']],
        trivia: ["\e[0;1;38;5;226;48;5;90m", ['A B C D ?']]
      }.freeze

      def initialize(doors:, on_open:, scene: nil, **kw)
        super(**kw)
        @doors   = doors
        @on_open = on_open
        @scene   = scene
        @art     = Arts.load(:modern, 'games_room')
      end

      attr_writer :scene

      def places = @doors
      def width = @art.cols
      def height = @art.rows + 5
      def activate = @on_open.call(chosen)

      private

      def at(door) = [@art.hotspot(:"label_#{door.name}").col, 0]

      def inside?(door, x, y)
        spot = @art.hotspot(:"label_#{door.name}")
        x.between?(spot.col, spot.col + spot.width - 1) && y.between?(0, spot.row)
      end

      def draw(frame, x, y)
        Rubbs::Modern::Art.draw(@art, frame, x: x, y: y)
        @doors.each do |door|
          lamp(frame, x, y, door)
          label(frame, x, y, door)
        end
        screen(frame, x, y, chosen)
        info(frame, x, y + @art.rows + 1)
      end

      # The station's name under it, lit when chosen; "Commodore " goes when
      # the name does not fit.
      def label(frame, x, y, door)
        spot  = @art.hotspot(:"label_#{door.name}")
        sgr   = door.equal?(chosen) ? "\e[0;1;38;5;16;48;5;209m" : "\e[0;38;5;209;48;5;236m"
        title = door.title.length > spot.width ? door.title.sub('Commodore ', '') : door.title
        write(frame, x + spot.col, y + spot.row, title.center(spot.width), sgr)
      end

      def inside(door) = @scene ? @scene.in_door(door.title) : 0

      def lamp(frame, x, y, door)
        n = inside(door)
        return unless n.positive?

        spot = @art.hotspot(:"lamp_#{door.name}")
        write(frame, x + spot.col, y + spot.row, '▄█▄', LIT)
        glow = @art.hotspot(:"glow_#{door.name}")
        write(frame, x + glow.col, y + glow.row, '░▒▓▒░', GLOW)
        count = @art.hotspot(:"count_#{door.name}")
        write(frame, x + count.col, y + count.row, n.to_s, LIT)
      end

      def screen(frame, x, y, door)
        sgr, lines = SCREENS.fetch(door.name)
        spot = @art.hotspot(:"screen_#{door.name}")
        lines.first(spot.height).each_with_index do |line, i|
          write(frame, x + spot.col, y + spot.row + i, line[0, spot.width].ljust(spot.width), sgr)
        end
      end

      def info(frame, x, y)
        door = chosen
        Rubbs::Modern::FrameBuffer.wrap_ansi(door.about.to_s, width).first(2).each_with_index do |line, i|
          write(frame, x, y + i, line.ljust(width), "\e[0;38;5;252m")
        end
        n = inside(door)
        who = n.zero? ? 'nobody inside right now' : "#{n} caller#{'s' unless n == 1} inside"
        write(frame, x, y + 2, "#{door.title} · #{who}".ljust(width), "\e[0;38;5;209m")
        write(frame, x, y + 3, '←→ or a click: another station · Enter: step in · Esc: back'.ljust(width), "\e[0;38;5;66m")
      end
    end
  end
end
