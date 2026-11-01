# frozen_string_literal: true

module UI
  module Modern
    # The colour of each part of the board. A window wears the colour of its
    # menu on its frame and on its focused title, the dashboard's panels the
    # colour of what they show, so a caller sees where a window belongs.
    module Accent
      COLORS = { board: 116, messages: 78, people: 176, doors: 209, you: 146,
                 help: 220 }.freeze

      def self.fg(section) = "\e[0;38;5;#{COLORS.fetch(section)};48;5;16m"

      def self.styles(section)
        c = COLORS.fetch(section)
        { window_border: "\e[0;38;5;#{c};48;5;16m", window_title: "\e[0;38;5;#{c};48;5;234m",
          window_title_focused: "\e[0;38;5;16;48;5;#{c}m" }.freeze
      end

      STYLES = COLORS.keys.to_h { |section| [section, styles(section)] }.freeze
    end

    # The window titles wear the icon of their part of the board, a CP437
    # sign each: the board ☼, messages ✉, people ☺, doors ♫, you ♥, help ¿.
    module Icon
      SIGNS = { board: '☼', messages: '✉', people: '☺', doors: '♫', you: '♥', help: '¿' }.freeze

      def self.title(section, text) = " #{SIGNS.fetch(section)} #{text} "

      # A window title without its icon: what the node list tells others.
      def self.strip(title) = title.to_s.strip.sub(/\A[#{SIGNS.values.join}] /o, '')
    end

    # The desktop: the clubhouse from the street (UI::Arts.house), lit
    # from the board's SceneModel: a window for each node taken, the door
    # and the lamp when anyone is in, smoke from the chimney while the live
    # chat talks, the mailbox flag and count for the caller's letters. Under
    # it two boards, who is inside (with the guestbook) and the notice board
    # (what is coming up, the new notes, the mail), and the graffiti wall
    # running along the bottom. A terminal smaller than 80×23 leaves the
    # house out. The application gives it its Data on start and every few
    # seconds after, and steps the smoke and the wall once a second.
    class Dashboard < BBS::Widget
      Data = Struct.new(:name, :registered, :caller_number, :node, :scene, keyword_init: true)

      W = "\e[0;38;5;231;48;5;16m"
      T = "\e[0;38;5;116;48;5;16m"
      D = "\e[0;38;5;66;48;5;16m"
      Y = "\e[0;38;5;220;48;5;16m"
      G = "\e[0;38;5;78;48;5;16m"

      TICKER_STEP = 2
      # The width the house and the boards are drawn in.
      WIDTH = 80
      # The rows of the house.
      HOUSE = 12
      # The windows of the house, one a node.
      WINDOWS = 7
      # The smoke from the chimney, a frame a second.
      SMOKE = [' ░▒░  ', ' ▒░ ░ ', '░ ▒░  ', ' ░ ▒░ '].freeze

      # Where a panel goes on the frame.
      Box = Struct.new(:x, :y, :width, :height)

      attr_writer :data
      # The room whose window is open (Clubhouse::Cards), its card over the
      # top of the house; nil for none.
      attr_writer :room

      def initialize(**kw)
        super
        @data  = nil
        @room  = nil
        @ticks = 0
        @house = nil
      end

      def tick! = @ticks += 1

      def render(frame)
        @bounds = parent.bounds.dup if parent&.bounds
        return if @data.nil? || bounds.width < 40 || bounds.height < 12

        width = [bounds.width - 4, WIDTH].min
        x = centred(width)
        y = top(frame, x, width)
        y += boards(frame, x, y, width)
        ticker(frame, x, [y + 1, bottom - 3].min, width)
      end

      private

      def scene = @data.scene

      def bottom = bounds.y + bounds.height

      # The column where something +width+ wide sits in the middle.
      def centred(width) = bounds.x + ((bounds.width - width) / 2)

      # The house, or on a small terminal the logo; returns the row under it.
      def top(frame, x, width)
        if bounds.width >= WIDTH && bounds.height >= 23
          house(frame, centred(WIDTH), bounds.y)
          bounds.y + HOUSE
        else
          header(frame, x, bounds.y + 1, width)
          bounds.y + 4
        end
      end

      # ── the house ────────────────────────────────────────────────────────

      def house(frame, x, y)
        art = Arts.house(:modern, scene.season)
        @house = house_scene(art) unless @house&.art.equal?(art)
        @house.layout(x, y, WIDTH, HOUSE)
        @house.render(frame)
        card(frame, x, y) if @room
      end

      # The card of the open room over the top of the house.
      def card(frame, x, y)
        art = Arts.load(:modern, "card_#{@room}")
        art.draw(frame, x: x, y: y)
        spot = art.hotspot(:about)
        frame.move(x + spot.col, y + spot.row)
        frame.write(Clubhouse::Cards::ABOUT.fetch(@room)[0, spot.width], sgr: "\e[0;38;5;252;48;5;234m")
      end

      def house_scene(art)
        s = BBS::Widgets::Scene.new(art: art)
        (1..WINDOWS).each { |n| s.fill(:"node_#{n}") { |spot| window(art, spot, n) } }
        light_up(s, art)
        s.fill(:flag)   { |spot| flag(art, spot) if scene.mail.positive? }
        s.fill(:mail)   { |spot| fill(art, spot, 231, "✉ #{scene.mail}".center(spot.width)) if scene.mail.positive? }
        s.fill(:status) { |spot| status(art, spot) }
        s
      end

      # The door, the lamp and the count while anyone is in; the smoke.
      def light_up(s, art)
        s.fill(:door)   { |spot| fill(art, spot, 220, '▒▒') if scene.inside.positive? }
        s.fill(:lamp)   { |spot| fill(art, spot, 226, '☼') if scene.inside.positive? }
        s.fill(:inside) { |spot| fill(art, spot, 230, "#{scene.inside}☺") if scene.inside.positive? }
        s.fill(:smoke)  { |spot| fill(art, spot, 250, SMOKE[@ticks % SMOKE.size]) if scene.smoking }
      end

      # A lit window: a node taken. The caller's own burns brighter.
      def window(art, spot, number)
        return nil unless scene.lit?(number)

        color = number == @data.node ? 226 : 220
        rows = Array.new(spot.height) { |i| "\e[0;38;5;#{color}#{Arts.bg(art, spot.col, spot.row + i)}m#{'▓' * spot.width}" }
        rows.join("\n")
      end

      def fill(art, spot, color, text)
        "\e[0;38;5;#{color}#{Arts.bg(art, spot.col, spot.row)}m#{text}"
      end

      def flag(art, spot)
        "\e[0;38;5;160#{Arts.bg(art, spot.col, spot.row)}m▄\n\e[0;38;5;160#{Arts.bg(art, spot.col, spot.row + 1)}m▌"
      end

      def status(art, spot)
        node  = @data.node ? "node #{@data.node} · " : ''
        lines = ["#{node}caller ##{@data.caller_number}", "Welcome, #{@data.name}!"]
        lines.each_with_index.map do |line, i|
          "\e[0;1;38;5;231#{Arts.bg(art, spot.col, spot.row + i)}m#{line[0, spot.width].rjust(spot.width)}"
        end.join("\n")
      end

      # The small terminal's top: the logo and the greeting.
      def header(frame, x, y, width)
        Logo.half_blocks.each_with_index do |line, i|
          frame.move(x, y + i)
          frame.write_ansi(line, base_sgr: W)
        end
        tx = x + Logo.width + 3
        return if tx + 16 > x + width

        node = @data.node ? " · node #{@data.node}" : ''
        ["#{T}Welcome, #{Y}#{@data.name}#{T}#{node}", "#{D}the Teletype BBS clubhouse"].each_with_index do |line, i|
          frame.move(tx, y + i)
          frame.write_ansi(BBS::FrameBuffer.clip_ansi(line, x + width - tx), base_sgr: T)
        end
      end

      # ── the two boards ───────────────────────────────────────────────────

      # The two boards; returns the rows they take.
      def boards(frame, x, y, width)
        room = bottom - 4 - y
        width >= 70 ? side_by_side(frame, x, y, width, room) : stacked(frame, x, y, width, room)
      end

      def side_by_side(frame, x, y, width, room)
        panel_w = (width - 2) / 2
        @inner  = panel_w - 4
        height  = room.clamp(4, 9)
        panel(frame, Box.new(x, y, panel_w, height), :people, 'INSIDE NOW', inside_lines(height - 2))
        panel(frame, Box.new(x + panel_w + 2, y, panel_w, height), :board, 'ON THE NOTICE BOARD', notice_lines)
        height
      end

      def stacked(frame, x, y, width, room)
        @inner = width - 4
        height = (room / 2).clamp(3, 6)
        panel(frame, Box.new(x, y, width, height), :people, 'INSIDE NOW', inside_lines(height - 2))
        panel(frame, Box.new(x, y + height, width, height), :board, 'ON THE NOTICE BOARD', notice_lines)
        height * 2
      end

      def panel(frame, box, section, title, lines)
        frame.box(x: box.x, y: box.y, width: box.width, height: box.height, sgr: Accent.fg(section), style: :single,
                  title: " #{title} ", title_sgr: Accent.styles(section)[:window_title_focused])
        lines.first(box.height - 2).each_with_index do |line, i|
          frame.move(box.x + 2, box.y + 1 + i)
          frame.write_ansi(BBS::FrameBuffer.clip_ansi(line, box.width - 4), base_sgr: T)
        end
      end

      # The nodes, then the guestbook: the last names that signed it.
      def inside_lines(rows)
        nodes = scene.nodes
        shown = nodes.size > rows - 1 ? nodes.first(rows - 2) : nodes
        lines = shown.map { |n| node_line(n) }
        lines << "#{D}  and #{nodes.size - shown.size} more inside" if shown.size < nodes.size
        lines << guestbook_line
      end

      def node_line(node)
        on  = Formatters.duration(Time.now - node.since)
        dot = node.number == @data.node ? "#{Y}●" : "#{G}●"
        "#{dot} #{W}#{node.name.to_s[0, 9].ljust(10)}#{D}#{node.activity.to_s[0, @inner - 18].ljust(@inner - 17)}#{T}#{on}"
      end

      def guestbook_line
        guests = scene.guestbook.map { |c| "#{c.username} #{c.timestamp.to_s[11, 5]}" }
        "#{D}guestbook: #{T}#{guests.empty? ? '(empty)' : guests.join(' · ')}"
      end

      # What is coming up, with a bar that fills as the day nears, then the
      # new notes on the cork board and the caller's letters.
      def notice_lines
        lines = scene.events.map { |e| event_line(e) }
        lines = ["#{D}(nothing scheduled yet)"] if lines.empty?
        lines << notes_line
        lines << "#{Y}✉ #{scene.mail} unread letter#{'s' unless scene.mail == 1}#{D} · F7 opens the mailbox" if
          scene.mail.positive?
        lines
      end

      def event_line(event)
        days = [((event.date - Time.now) / 86_400).ceil, 0].max
        left = days.zero? ? 'today' : "#{days} day#{'s' unless days == 1}"
        bar  = ((30 - days.clamp(0, 30)) * 3 / 30.0).round
        "#{W}#{event.name[0, @inner - 12].ljust(@inner - 11)}#{Y}#{'▓' * bar}#{D}#{'░' * (3 - bar)} #{T}#{left.rjust(7)}"
      end

      def notes_line
        notes = scene.notes
        return "#{D}no new notes on the cork board" if notes.zero?

        "#{G}#{notes} new note#{'s' unless notes == 1} #{D}on the cork board (F2)"
      end

      # The graffiti wall (the oneliners) as one line running from right to left.
      def ticker(frame, x, y, width)
        return if width < 20

        label = "#{Accent.fg(:messages)}✎ graffiti ▸ "
        frame.move(x, y)
        frame.write_ansi(label, base_sgr: T)
        room = width - 13
        text = scene.oneliners.map { |o| "#{o.username}: #{o.text}" }.join('  ···  ')
        text = '(the wall is bare: Messages > Oneliners)' if text.empty?
        line = if text.length <= room
                 text
               else
                 loop_text = "#{text}  ···  "
                 start = (@ticks * TICKER_STEP) % loop_text.length
                 (loop_text * 2)[start, room]
               end
        frame.move(x + 13, y)
        frame.write(line.ljust(room), sgr: T)
      end
    end
  end
end
