# frozen_string_literal: true

require_relative 'canvas'

module UI
  module Petscii
    # The gate's menu on a C64, drawn on a Canvas in the greens of a phosphor
    # screen: code rain falls down the screen behind everything else, the
    # boards are the nodes of a list in a thin frame, one row each, and the
    # chosen one is lit. Under the
    # frame the chosen node's address, tags and link. A page holds eight
    # nodes; the empty places are unassigned, so the next board has somewhere
    # to go, and more than eight turn into pages.
    class Switchboard
      PER_PAGE = 8

      RAIN_ROWS = (0..22)
      RAIN_COLS = (0..38)
      DROPS     = 7
      # A drop from its head up: the head white, the trail fading out.
      TRAIL = [Canvas::WHITE, Canvas::LIGHT_GREEN, Canvas::GREEN, Canvas::GREEN, Canvas::DARK_GREY].freeze
      RAIN  = %w[0 1 2 3 4 5 6 7 8 9 A E K N R T X Z $ + < > = : π ╳ ┼ ▚ ▖ ▝ £].freeze

      LOGO_TOP = 1
      # The letters, 4×6 pixels, two pixel rows to a cell in the half blocks.
      FONT = {
        'T' => %w[#### .##. .##. .##. .##. .##.],
        'G' => %w[#### #... #... #.## #..# ####],
        'A' => %w[#### #..# #..# #### #..# #..#],
        'E' => %w[#### #... ###. #... #... ####],
        ' ' => %w[.. .. .. .. .. ..]
      }.freeze
      HALVES = { '..' => ' ', '#.' => '▀', '.#' => '▄', '##' => '█' }.freeze
      LOGO_COLORS = [Canvas::LIGHT_GREEN, Canvas::LIGHT_GREEN, Canvas::GREEN].freeze

      TAGLINE     = 'JACK INTO THE TELETYPE NETWORK'
      TAGLINE_ROW = 5

      FRAME_TOP    = 7
      FRAME_BOTTOM = FRAME_TOP + PER_PAGE + 1
      FRAME_LEFT   = 3
      FRAME_RIGHT  = 36
      NODE_COL     = FRAME_LEFT + 1
      NODE_WIDTH   = FRAME_RIGHT - FRAME_LEFT - 1
      NAME_WIDTH   = 16

      ADDR_ROW    = FRAME_BOTTOM + 2
      TAGS_ROW    = ADDR_ROW + 1
      LINK_ROW    = ADDR_ROW + 2
      VALUE_COL   = NODE_COL + 6
      VALUE_WIDTH = FRAME_RIGHT - VALUE_COL
      BAR         = 12

      HELP_ROW   = 23
      REST_ROW   = 24
      HELP       = [['CRSR', true], ['  ', false], ['RETURN', true], [' JACK IN  ', false],
                    ['G', true], [' WORLD  ', false], ['Q', true], [' EXIT', false]].freeze
      HELP_PAGES = [['RETURN', true], [' JACK IN ', false], ['+/-', true], [' PAGE  ', false],
                    ['G', true], [' WORLD  ', false], ['Q', true], [' EXIT', false]].freeze

      Drop = Struct.new(:col, :head, :glyphs)
      # What a node shows: its +name+, the +right+ text at the frame's edge,
      # the +mark+ glyph in +mark_color+ (+lit_mark+ when chosen, reversed),
      # and the three info lines under the frame.
      Node = Data.define(:name, :right, :mark, :mark_color, :lit_mark, :addr, :tags, :link)

      attr_reader :page, :index

      def initialize(boards, random: Random.new)
        @boards = boards
        @random = random
        @page   = 0
        @index  = 0
        @drops  = []
        spawn(@random.rand(RAIN_ROWS.size + TRAIL.size)) while @drops.size < DROPS
      end

      def pages = [(@boards.size + PER_PAGE - 1) / PER_PAGE, 1].max

      def on_page = @boards[@page * PER_PAGE, PER_PAGE] || []

      def selected = on_page[@index]

      # The board of digit +n+ on this page, nil when that place is empty.
      def board_at(digit) = on_page[digit - 1]

      # The whole screen.
      def frame
        canvas = Canvas.new
        residue(canvas)
        @drops.each { |drop| trail(canvas, drop) }
        logo(canvas)
        canvas.text(TAGLINE_ROW, centre(tagline), tagline, Canvas::GREEN)
        border(canvas)
        PER_PAGE.times { |slot| node(canvas, slot) }
        labels(canvas)
        info(canvas)
        help(canvas)
        canvas.frame + rest
      end

      # Moves the selection +delta+ nodes down; past the first or the last
      # node it turns the page. Returns the bytes that repaint what changed:
      # the two nodes and the info, or the whole screen for a page.
      def move(delta)
        slot = @index + delta
        if slot.negative? && @page.positive?
          @page -= 1
          @index = on_page.size - 1
          frame
        elsif slot >= on_page.size && @page < pages - 1
          @page += 1
          @index = 0
          frame
        else
          select(slot.clamp(0, on_page.size - 1))
        end
      end

      # Turns to the page +delta+ away; the whole screen, or nothing when
      # there is no such page.
      def turn(delta)
        target = @page + delta
        return ''.b unless target.between?(0, pages - 1)

        @page  = target
        @index = 0
        frame
      end

      # Selects +slot+ on this page; the repaint of the old and the new node
      # and of the info.
      def select(slot)
        return ''.b if slot == @index || slot.negative? || slot >= on_page.size

        old = @index
        @index = slot
        node_span(old) + node_span(slot) + info_spans + rest
      end

      # The rain falls a row: an idle tick. Only the cells of the drops go
      # out, the cursor stepping from one to the next.
      def rain
        canvas = Canvas.new
        cells = []
        @drops.each do |drop|
          drop.head += 1
          drop.glyphs[drop.head] = RAIN.sample(random: @random)
          cells.concat(trail(canvas, drop))
          cells << drip(canvas, drop.head - TRAIL.size, drop.col, ' ', nil)
        end
        @drops.reject! { |drop| drop.head - TRAIL.size >= RAIN_ROWS.last }
        spawn(0) while @drops.size < DROPS
        canvas.patch(cells.compact) + rest
      end

      # The dialling of the selected board: its node flashes, the link bar
      # fills, the carrier comes. Each step's bytes, to go out with a pause
      # after them.
      def dial_steps
        slot  = @index
        steps = []
        2.times { steps << node_span(slot, flash: true) << node_span(slot, flash: false) }
        (0..BAR).step(2) do |filled|
          steps << link([['HANDSHAKE ', Canvas::GREEN], ['█' * filled, Canvas::LIGHT_GREEN],
                         ['▒' * (BAR - filled), Canvas::DARK_GREY]])
        end
        steps << link([['CARRIER DETECTED', Canvas::LIGHT_GREEN]])
        steps << link([['JACKING IN', Canvas::WHITE]])
        steps
      end

      def self.color(board) = UI::Colors.c64(board.rgb)

      private

      # -- what a subclass changes: the nodes, the words, the help ---------

      # The Node of +board+ (a BoardModel): a block of its colour, the port.
      def node_view(board)
        Node.new(name: board.name, right: board.port.to_s, mark: '▌', mark_color: Switchboard.color(board), lit_mark: ' ',
                 addr: board.address, tags: board.tags.join('/'), link: 'STANDBY')
      end

      def name_width = NAME_WIDTH

      def title = ' TTG NETWORK '

      def tagline = TAGLINE

      def info_labels = %w[ADDR TAGS LINK]

      def help_parts = pages > 1 ? HELP_PAGES : HELP

      def rest = Canvas.new.cursor(REST_ROW, 0)

      def centre(text) = (Canvas::COLS - text.length) / 2

      # A new drop, half of them in the open columns beside the frame.
      def spawn(head)
        free = RAIN_COLS.to_a - @drops.map(&:col)
        open = free.grep_v(FRAME_LEFT..FRAME_RIGHT)
        free = open if open.any? && @random.rand < 0.5
        drop = Drop.new(free.sample(random: @random), head, {})
        ((head - TRAIL.size + 1)..head).each { |row| drop.glyphs[row] = RAIN.sample(random: @random) }
        @drops << drop
      end

      # The cells of the logo, the tagline, the frame and the info; the rain
      # falls behind them.
      def solid
        @solid ||= begin
          logo = logo_cells.keys
          rows = logo.map(&:first)
          cols = logo.map(&:last)
          [[rows.minmax, cols.minmax],
           [[TAGLINE_ROW] * 2, [centre(tagline), centre(tagline) + tagline.length - 1]],
           [[FRAME_TOP, FRAME_BOTTOM], [FRAME_LEFT, FRAME_RIGHT]],
           [[ADDR_ROW, LINK_ROW], [FRAME_LEFT, FRAME_RIGHT]]].each_with_object({}) do |((top, bottom), (left, right)), cells|
            (top..bottom).each { |row| (left..right).each { |col| cells[[row, col]] = true } }
          end
        end
      end

      # A cell of rain, unless it is off the rain or behind the logo; its
      # position when it was drawn.
      def drip(canvas, row, col, glyph, color)
        return unless RAIN_ROWS.cover?(row) && !solid[[row, col]]

        canvas.text(row, col, glyph, color)
        [row, col]
      end

      def trail(canvas, drop)
        TRAIL.each_with_index.map do |color, i|
          row = drop.head - i
          drip(canvas, row, drop.col, drop.glyphs.fetch(row, ' '), color)
        end
      end

      # Old rain, dim, left on the glass.
      def residue(canvas)
        RAIN_ROWS.each do |row|
          RAIN_COLS.each do |col|
            chance = @random.rand
            next if chance > 0.1

            drip(canvas, row, col, RAIN.sample(random: @random), chance < 0.02 ? Canvas::GREEN : Canvas::DARK_GREY)
          end
        end
      end

      # The cells of TTG GATE: [row, col] => [glyph, colour].
      def logo_cells
        @logo_cells ||= begin
          pixels = 6.times.map { |r| 'TTG GATE'.chars.map { |c| FONT.fetch(c)[r] }.join('.') }
          left = centre(pixels.first)
          cells = {}
          3.times do |r|
            pixels.first.length.times do |c|
              glyph = HALVES.fetch(pixels[2 * r][c] + pixels[(2 * r) + 1][c])
              cells[[LOGO_TOP + r, left + c]] = [glyph, LOGO_COLORS[r]] unless glyph == ' '
            end
          end
          cells
        end
      end

      def logo(canvas) = logo_cells.each { |(row, col), (glyph, color)| canvas.text(row, col, glyph, color) }

      def border(canvas)
        [FRAME_TOP, FRAME_BOTTOM].each do |row|
          canvas.text(row, FRAME_LEFT, "┼#{'─' * NODE_WIDTH}┼", Canvas::DARK_GREY)
        end
        ((FRAME_TOP + 1)...FRAME_BOTTOM).each do |row|
          canvas.text(row, FRAME_LEFT, '│', Canvas::DARK_GREY)
          canvas.text(row, FRAME_RIGHT, '│', Canvas::DARK_GREY)
        end
      end

      def labels(canvas)
        canvas.text(FRAME_TOP, FRAME_LEFT + 2, title, Canvas::GREEN)
        page = " PAGE #{@page + 1}/#{pages} "
        canvas.text(FRAME_TOP, FRAME_RIGHT - 1 - page.length, page, Canvas::GREEN)
        site = ' TELETYPEGAMES.ORG '
        canvas.text(FRAME_BOTTOM, FRAME_RIGHT - 1 - site.length, site, Canvas::DARK_GREY)
        [ADDR_ROW, TAGS_ROW, LINK_ROW].zip(info_labels) { |row, label| canvas.text(row, NODE_COL, label, Canvas::DARK_GREY) }
      end

      # A node: its key, its mark (a board's colour), its name, a dotted
      # leader and the text at the edge (the port); the chosen one lit in
      # green, or white while it flashes. An empty place is unassigned.
      def node(canvas, slot, flash: false)
        row   = FRAME_TOP + 1 + slot
        board = on_page[slot]
        canvas.clear(row, NODE_COL, NODE_WIDTH)
        key = format('%02d', slot + 1)
        return canvas.text(row, NODE_COL + 1, "#{key}   [ UNASSIGNED ]", Canvas::DARK_GREY) unless board

        view   = node_view(board)
        right  = view.right.to_s.upcase
        edge   = FRAME_RIGHT - 1 - right.length
        name   = view.name.to_s.upcase[0, [name_width, edge - 2 - (NODE_COL + 6)].min]
        leader = '.' * [edge - 1 - (NODE_COL + 6 + name.length + 1), 0].max
        if slot == @index
          lit = flash ? Canvas::WHITE : Canvas::LIGHT_GREEN
          canvas.text(row, NODE_COL, ">#{key}   #{name} #{leader} #{right}".ljust(NODE_WIDTH), lit, rvs: true)
          canvas.text(row, NODE_COL + 4, view.lit_mark, view.mark_color, rvs: true)
        else
          canvas.text(row, NODE_COL + 1, key, Canvas::DARK_GREY)
          canvas.text(row, NODE_COL + 4, view.mark, view.mark_color)
          canvas.text(row, NODE_COL + 6, name, Canvas::GREEN)
          canvas.text(row, NODE_COL + 6 + name.length + 1, leader, Canvas::DARK_GREY)
          canvas.text(row, edge, right, Canvas::GREEN)
        end
      end

      def node_span(slot, flash: false)
        canvas = Canvas.new
        node(canvas, slot, flash: flash)
        canvas.span(FRAME_TOP + 1 + slot, NODE_COL, NODE_WIDTH)
      end

      def info(canvas)
        [ADDR_ROW, TAGS_ROW, LINK_ROW].each { |row| canvas.clear(row, VALUE_COL, VALUE_WIDTH) }
        board = selected
        return unless board

        view = node_view(board)
        canvas.text(ADDR_ROW, VALUE_COL, view.addr.to_s.upcase[0, VALUE_WIDTH], Canvas::LIGHT_GREEN)
        canvas.text(TAGS_ROW, VALUE_COL, view.tags.to_s.upcase[0, VALUE_WIDTH], Canvas::GREEN)
        canvas.text(LINK_ROW, VALUE_COL, view.link.to_s.upcase[0, VALUE_WIDTH], Canvas::GREEN)
      end

      def info_spans
        canvas = Canvas.new
        info(canvas)
        [ADDR_ROW, TAGS_ROW, LINK_ROW].map { |row| canvas.span(row, VALUE_COL, VALUE_WIDTH) }.join
      end

      # The link line, from +parts+ of [text, colour].
      def link(parts)
        canvas = Canvas.new
        col = VALUE_COL
        parts.each do |text, color|
          canvas.text(LINK_ROW, col, text, color)
          col += text.length
        end
        canvas.span(LINK_ROW, VALUE_COL, VALUE_WIDTH)
      end

      def help(canvas)
        parts = help_parts
        col = centre(parts.map(&:first).join)
        parts.each do |text, key|
          canvas.text(HELP_ROW, col, text, key ? Canvas::GREEN : Canvas::DARK_GREY)
          col += text.length
        end
      end
    end
  end
end
