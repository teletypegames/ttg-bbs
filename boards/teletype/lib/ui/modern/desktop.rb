# frozen_string_literal: true

module UI
  module Modern
    # The colour of each part of the board. A window wears the colour of its
    # menu on its frame and on its focused title, the dashboard's panels the
    # colour of what they show, so a caller sees where a window belongs.
    module Accent
      COLORS = { board: 116, messages: 78, files: 214, read: 111, people: 176, doors: 209, you: 146,
                 help: 220 }.freeze

      def self.fg(section) = "\e[0;38;5;#{COLORS.fetch(section)};48;5;16m"

      def self.styles(section)
        c = COLORS.fetch(section)
        { window_border: "\e[0;38;5;#{c};48;5;16m", window_title: "\e[0;38;5;#{c};48;5;234m",
          window_title_focused: "\e[0;38;5;16;48;5;#{c}m" }.freeze
      end

      STYLES = COLORS.keys.to_h { |section| [section, styles(section)] }.freeze
    end

    # The desktop while no art is chosen: the board as it is now. The logo
    # and the greeting, the TTG Gate banner, then four panels (the nodes, the last callers, the
    # new releases, what is coming up) and the oneliners wall running along
    # the bottom. The application gives it its Data on start and every few
    # seconds after, and steps the ticker once a second.
    class Dashboard < BBS::Widget
      Data = Struct.new(:name, :registered, :caller_number, :node, :nodes, :callers, :releases, :events,
                        :oneliners, :messages, keyword_init: true)

      W = "\e[0;38;5;231;48;5;16m"
      T = "\e[0;38;5;116;48;5;16m"
      D = "\e[0;38;5;66;48;5;16m"
      Y = "\e[0;38;5;220;48;5;16m"

      TICKER_STEP = 2

      GATE      = 'TTG GATE  ·  telnet teletypegames.org 2399'
      GATE_NOTE = 'the whole Teletype Games BBS Network, every board from one place'
      GATE_SGR  = "\e[0;1;38;5;220;48;5;52m"

      attr_writer :data

      def initialize(**kw)
        super
        @data  = nil
        @ticks = 0
      end

      def tick! = @ticks += 1

      def render(frame)
        @bounds = parent.bounds.dup if parent&.bounds
        return if @data.nil? || bounds.width < 40 || bounds.height < 12

        x = bounds.x + 2
        y = bounds.y + 1
        width = bounds.width - 4
        header(frame, x, y, width)
        y += 4
        gate(frame, x, y, width)
        y += 5
        columns = width >= 70 ? 2 : 1
        panel_w = columns == 2 ? (width - 2) / 2 : width
        @inner  = panel_w - 4
        room    = bounds.y + bounds.height - 4 - y
        panel_h = columns == 2 ? (room / 2).clamp(4, 7) : (room / 4).clamp(3, 6)
        panels.each_with_index do |(section, title, lines), i|
          px = x + (columns == 2 ? (i % 2) * (panel_w + 2) : 0)
          py = y + ((i / columns) * panel_h)
          break if py + panel_h > bounds.y + bounds.height - 3

          panel(frame, px, py, panel_w, panel_h, section, title, lines)
        end
        ticker(frame, x, bounds.y + bounds.height - 3, width)
      end

      private

      def header(frame, x, y, width)
        logo = Logo.half_blocks
        logo.each_with_index do |line, i|
          frame.move(x, y + i)
          frame.write_ansi(line, base_sgr: W)
        end
        tx = x + Logo.width + 4
        return if tx + 20 > x + width

        name  = "#{Y}#{@data.name}#{T}"
        node  = @data.node ? " · node #{@data.node}" : ''
        guest = if @data.registered then 'registered · You > Profile… edits your page'
                elsif @data.name == AccountService::ANONYMOUS then 'anonymous · call with a name to keep one'
                else 'a guest · You > Register… keeps your name'
                end
        lines = ["#{T}Welcome, #{name} · caller ##{@data.caller_number}#{node}",
                 "#{D}#{guest}",
                 "#{D}F10 menus · F1 the TTG Master · Alt-X bye"]
        lines.each_with_index do |line, i|
          frame.move(tx, y + i)
          frame.write_ansi(BBS::FrameBuffer.clip_ansi(line, x + width - tx), base_sgr: T)
        end
      end

      # The one port to every board of ours, big, under the greeting.
      def gate(frame, x, y, width)
        frame.box(x: x, y: y, width: width, height: 4, sgr: GATE_SGR, fill_sgr: GATE_SGR, style: :double)
        [GATE, GATE_NOTE].each_with_index do |text, i|
          text = text[0, width - 4]
          frame.move(x + ((width - text.length) / 2), y + 1 + i)
          frame.write(text, sgr: i.zero? ? "\e[0;1;38;5;231;48;5;52m" : GATE_SGR)
        end
      end

      def panels
        [[:people, 'On line now', nodes_lines], [:files, "What's new", release_lines],
         [:people, 'Last callers', caller_lines], [:board, 'Coming up', event_lines]]
      end

      def panel(frame, x, y, width, height, section, title, lines)
        frame.box(x: x, y: y, width: width, height: height, sgr: Accent.fg(section), style: :single,
                  title: " #{title} ", title_sgr: Accent.styles(section)[:window_title_focused])
        inner = width - 4
        lines.first(height - 2).each_with_index do |line, i|
          frame.move(x + 2, y + 1 + i)
          frame.write_ansi(BBS::FrameBuffer.clip_ansi(line, inner), base_sgr: T)
        end
      end

      def nodes_lines
        return ["#{D}(nobody else on the lines)"] if @data.nodes.empty?

        @data.nodes.map do |n|
          "#{Y}#{n.number.to_s.rjust(2)}#{T} #{W}#{n.name.to_s[0, 14].ljust(15)}#{D}#{n.activity}"
        end
      end

      def caller_lines
        return ["#{D}(no calls yet)"] if @data.callers.empty?

        @data.callers.map do |c|
          "#{W}#{c.username.to_s[0, 16].ljust(17)}#{D}#{c.timestamp.to_s[5, 11].sub('T', ' ')}"
        end
      end

      def release_lines
        return ["#{D}(no releases)"] if @data.releases.empty?

        @data.releases.map do |g|
          "#{Y}#{g.title}#{T} #{g.version} #{D}#{g.platform} #{g.released_at&.strftime('%m-%d')}"
        end
      end

      # Each event on two lines at most: when, then its name, wrapped under it.
      def event_lines
        lines = @data.events.first(2).flat_map do |e|
          days  = ((e.date - Time.now) / 86_400).ceil
          when_ = days <= 0 ? 'today' : "in #{days} day#{'s' unless days == 1}"
          name  = BBS::FrameBuffer.wrap_ansi(e.name, [@inner - 12, 10].max).first(2)
          name.each_with_index.map { |part, i| "#{Y}#{(i.zero? ? when_ : '').ljust(12)}#{W}#{part}" }
        end
        lines = ["#{D}(nothing scheduled)"] if lines.empty?
        lines + ["#{D}#{@data.messages} messages on the boards"]
      end

      # The oneliners wall as one line running from right to left.
      def ticker(frame, x, y, width)
        return if width < 20

        label = "#{Accent.fg(:messages)}oneliners ▸ "
        frame.move(x, y)
        frame.write_ansi(label, base_sgr: T)
        room = width - 12
        text = @data.oneliners.map { |o| "#{o.username}: #{o.text}" }.join('   ·   ')
        text = '(the wall is empty: Messages > Oneliners)' if text.empty?
        line = if text.length <= room
                 text
               else
                 loop_text = "#{text}   ·   "
                 start = (@ticks * TICKER_STEP) % loop_text.length
                 (loop_text * 2)[start, room]
               end
        frame.move(x + 12, y)
        frame.write(line.ljust(room), sgr: T)
      end
    end
  end
end
